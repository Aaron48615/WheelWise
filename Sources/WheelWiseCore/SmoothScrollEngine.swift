import Foundation

/// 单轴平滑滚动：把离散的“行数”累积起来，按指数缓动逐帧吐出像素。
///
/// 数学：每帧输出 remaining × (1 − e^(−dt/τ))，τ 是时间常数。
/// 剩余量小于半像素时一步走完，保证收敛且总量精确。
public struct SmoothScrollEngine {
    public let timeConstant: Double
    public let pixelsPerLine: Double
    public private(set) var remainingLines: Double = 0

    public init(timeConstant: Double = 0.055, pixelsPerLine: Double = 36) {
        self.timeConstant = timeConstant
        self.pixelsPerLine = pixelsPerLine
    }

    public var isIdle: Bool { remainingLines == 0 }

    public mutating func add(lines: Double) {
        remainingLines += lines
    }

    /// 推进 dt 秒，返回本帧应输出的像素增量；空闲时返回 nil。
    public mutating func tick(dt: Double) -> Double? {
        guard remainingLines != 0, dt > 0 else { return nil }
        let fraction = 1 - exp(-dt / timeConstant)
        var step = remainingLines * fraction
        // 剩余量不足半像素时直接走完，避免无限逼近。
        let epsilonLines = 0.5 / pixelsPerLine
        if abs(remainingLines) - abs(step) < epsilonLines {
            step = remainingLines
        }
        remainingLines -= step
        return step * pixelsPerLine
    }
}

/// 双轴平滑滚动的状态机：决定每帧输出哪些事件（began / changed / ended），
/// 让 App 把合成事件当作一次真实的触控板式滚动来渲染。
///
/// 线程安全：add()（事件 tap 线程）与 tick()（定时器线程）都会加锁。
public final class SmoothScrollController {
    public struct Emission: Equatable, Sendable {
        public let phase: SyntheticScrollPhase
        public let pixelsY: Double
        public let pixelsX: Double
    }

    /// 一“行”对应的像素数（决定滚轮一格滚多远）。
    public let pixelsPerLine: Double

    /// 速度倍率，作用于新累积的行数。
    public var speed: Double = 1.0

    private var vertical: SmoothScrollEngine
    private var horizontal: SmoothScrollEngine
    private var active = false
    private var needsEnd = false
    private let lock = NSLock()

    public init(timeConstant: Double = 0.055, pixelsPerLine: Double = 36) {
        self.pixelsPerLine = pixelsPerLine
        vertical = SmoothScrollEngine(timeConstant: timeConstant, pixelsPerLine: pixelsPerLine)
        horizontal = SmoothScrollEngine(timeConstant: timeConstant, pixelsPerLine: pixelsPerLine)
    }

    /// 离散事件到来：按速度倍率累积行数。
    public func add(linesY: Double, linesX: Double) {
        lock.lock()
        defer { lock.unlock() }
        vertical.add(lines: linesY * speed)
        horizontal.add(lines: linesX * speed)
    }

    public var isIdle: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !active && !needsEnd && vertical.isIdle && horizontal.isIdle
    }

    /// 推进一帧，返回 0..2 条要发送的事件：
    /// 第一条是带增量的 began/changed，动画收尾时附加一条 ended。
    public func tick(dt: Double) -> [Emission] {
        lock.lock()
        defer { lock.unlock() }
        let dy = vertical.tick(dt: dt)
        let dx = horizontal.tick(dt: dt)
        guard dy != nil || dx != nil else {
            guard needsEnd else { return [] }
            needsEnd = false
            active = false
            return [Emission(phase: .ended, pixelsY: 0, pixelsX: 0)]
        }
        let phase: SyntheticScrollPhase = active ? .changed : .began
        active = true
        needsEnd = true
        return [Emission(phase: phase, pixelsY: dy ?? 0, pixelsX: dx ?? 0)]
    }
}
