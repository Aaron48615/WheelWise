import AppKit
import CoreGraphics
import Foundation
import WheelWiseCore
import CWheelWiseShim

/// CGEventTap 生命周期 + 事件分流处理 + 合成事件发送。
///
/// 事件分流规则（未打标记的 scrollWheel 事件）：
/// - 离散（滚轮鼠标）：平滑滚动开启 → 吞掉并交给平滑引擎；否则按设置反转后放行。
/// - 连续（触控板/触面）：默认原样放行；Magic Mouse 实验模式开启时才反转。
/// - 打了 syntheticTag 的事件：自己发的，直接放行（防回环）。
final class ScrollTap {
    private let settings: WheelWiseSettings
    private let frontmost: FrontmostAppObserver
    private let smooth: SmoothScrollController

    private let stateLock = NSLock()
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?

    private var timer: DispatchSourceTimer?
    private var lastFire: DispatchTime?
    private let smoothQueue = DispatchQueue(label: "com.wheelwise.smooth", qos: .userInteractive)

    init(settings: WheelWiseSettings, frontmost: FrontmostAppObserver) {
        self.settings = settings
        self.frontmost = frontmost
        smooth = SmoothScrollController()
    }

    /// 幂等：已有 tap 则仅重新启用（覆盖被系统禁用的情况）。
    func start() {
        stateLock.lock()
        let existing = tap
        stateLock.unlock()
        if existing != nil {
            WWEventTapEnable(existing!, true)
            return
        }
        let thread = Thread { [weak self] in self?.threadMain() }
        thread.name = "com.wheelwise.eventtap"
        thread.start()
        startTimerIfNeeded()
    }

    func setEnabled(_ enabled: Bool) {
        stateLock.lock()
        let current = tap
        stateLock.unlock()
        if let current {
            WWEventTapEnable(current, enabled)
        }
    }

    private func threadMain() {
        let mask = CGEventMask(1) << UInt64(CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("WheelWise: 创建事件 tap 失败，通常是辅助功能权限未授予")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let runLoop = RunLoop.current.getCFRunLoop()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        stateLock.lock()
        self.tap = tap
        self.runLoop = runLoop
        stateLock.unlock()
        WWEventTapEnable(tap, true)
        RunLoop.current.run()
    }

    private static let tapCallback: CGEventTapCallBack = { _, _, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let tap = Unmanaged<ScrollTap>.fromOpaque(userInfo).takeUnretainedValue()
        return tap.process(event: event)
    }

    // MARK: - 事件处理

    func process(event: CGEvent) -> Unmanaged<CGEvent>? {
        // 自己发出的合成事件直接放行。
        if ScrollWheelEventIO.isSynthetic(event) {
            return Unmanaged.passUnretained(event)
        }
        guard settings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }
        if let id = frontmost.bundleID, settings.ignoredApps.contains(id) {
            return Unmanaged.passUnretained(event)
        }

        switch ScrollWheelEventIO.source(of: event) {
        case .wheel:
            if settings.smoothScrolling {
                smooth.speed = settings.scrollSpeed
                // 方向取负与反转路径保持一致：引擎吃的是“原始”增量，
                // 不取负的话平滑滚动的方向会回到系统默认（反向）
                let signY: Double = settings.reverseVertical ? -1 : 1
                let signX: Double = settings.reverseHorizontal ? -1 : 1
                smooth.add(
                    linesY: signY * amount(
                        lines: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
                        points: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
                    ),
                    linesX: signX * amount(
                        lines: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
                        points: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
                    )
                )
                return nil // 吞掉原始离散事件
            }
            ScrollWheelEventIO.applyReverse(
                to: event,
                vertical: settings.reverseVertical,
                horizontal: settings.reverseHorizontal
            )
            return Unmanaged.passUnretained(event)

        case .continuousSurface:
            if settings.magicMouseMode {
                ScrollWheelEventIO.applyReverse(
                    to: event,
                    vertical: settings.reverseVertical,
                    horizontal: settings.reverseHorizontal
                )
            }
            return Unmanaged.passUnretained(event)
        }
    }

    /// 离散事件量：行数为准；个别高分辨率滚轮只有像素值，按 10px/行 折算。
    private func amount(lines: Int64, points: Int64) -> Double {
        if lines != 0 { return Double(lines) }
        if points != 0 { return Double(points) / 10.0 }
        return 0
    }

    // MARK: - 平滑滚动发送

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: smoothQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 120.0, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.smoothTick() }
        timer.resume()
        self.timer = timer
    }

    private func smoothTick() {
        let now = DispatchTime.now()
        let dt: Double
        if let last = lastFire {
            dt = Double(now.uptimeNanoseconds &- last.uptimeNanoseconds) / 1e9
        } else {
            dt = 1.0 / 120.0
        }
        lastFire = now
        for emission in smooth.tick(dt: min(dt, 0.1)) {
            post(emission: emission)
        }
    }

    private func post(emission: SmoothScrollController.Emission) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: ScrollWheelEventIO.syntheticTag)
        // 像素增量用 Double 原值写入，保留小数部分让 120Hz 下的动画更顺滑
        SyntheticScrollEventBuilder.apply(
            event,
            pixelsY: emission.pixelsY,
            pixelsX: emission.pixelsX,
            phase: emission.phase
        )
        event.post(tap: .cghidEventTap)
    }
}
