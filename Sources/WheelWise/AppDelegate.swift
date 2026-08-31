import AppKit
import ApplicationServices
import SwiftUI
import WheelWiseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = WheelWiseSettings()
    let frontmost = FrontmostAppObserver()

    private var tap: ScrollTap?
    private var menuController: MenuBarController?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var pollTimer: Timer?
    private let settingsModel = SettingsModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        frontmost.start()
        setupMenu()
        tap = ScrollTap(settings: settings, frontmost: frontmost)

        if AXIsProcessTrusted() && settings.isEnabled {
            tap?.start()
        }
        startPolling()

        if !AXIsProcessTrusted() {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tap?.setEnabled(false)
    }

    // MARK: - 菜单

    private func setupMenu() {
        let controller = MenuBarController()
        controller.onToggle = { [weak self] enabled in
            guard let self else { return }
            self.settings.isEnabled = enabled
            self.refreshTapState()
        }
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        controller.refresh(enabled: settings.isEnabled)
        controller.show()
        menuController = controller
    }

    // MARK: - Tap 状态

    func refreshTapState() {
        menuController?.refresh(enabled: settings.isEnabled)
        guard let tap else { return }
        if settings.isEnabled && AXIsProcessTrusted() {
            tap.start()
        } else {
            tap.setEnabled(false)
        }
    }

    private func startPolling() {
        // 轮询做两件事：权限被撤回时重新引导；tap 被系统禁用时重新启用。
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            if onboardingWindow?.isVisible == true {
                onboardingWindow?.orderOut(nil)
            }
            if settings.isEnabled {
                tap?.start() // 已存在则只是重新启用，幂等
            }
        } else {
            tap?.setEnabled(false)
            if onboardingWindow?.isVisible != true {
                showOnboarding()
            }
        }
    }

    // MARK: - 窗口

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "WheelWise 设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: SettingsView(
                    onEnabledChanged: { [weak self] in self?.refreshTapState() },
                    model: settingsModel
                )
            )
            window.center()
            settingsWindow = window
        }
        // 在窗口抢走焦点之前快照前台应用，“添加刚才的前台应用”才有意义
        settingsModel.refreshPreviousApp()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "WheelWise"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: OnboardingView(onOpenSettings: Self.openAccessibilitySettings)
            )
            window.center()
            onboardingWindow = window

            // 触发系统原生授权弹窗。这一步会把 WheelWise 自动注册进
            // 「辅助功能」列表（否则列表里根本不会出现本应用，手动添加
            // 还容易被过期授权记录干扰）。
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
