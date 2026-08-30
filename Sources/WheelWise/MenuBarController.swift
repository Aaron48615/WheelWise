import AppKit

final class MenuBarController: NSObject {
    var onToggle: ((Bool) -> Void)?
    var onOpenSettings: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var enabled = true

    func show() {
        guard let button = statusItem.button else { return }
        let icon = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "WheelWise")
            ?? NSImage(systemSymbolName: "magicmouse", accessibilityDescription: "WheelWise")
        icon?.isTemplate = true
        button.image = icon
        buildMenu()
    }

    func refresh(enabled: Bool) {
        self.enabled = enabled
        statusItem.button?.contentTintColor = enabled ? nil : .disabledControlTextColor
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: enabled ? "已开启（点击关闭）" : "已关闭（点击开启）",
            action: #selector(toggleClicked),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = enabled ? .on : .off
        menu.addItem(toggle)

        let settings = NSMenuItem(title: "设置…", action: #selector(settingsClicked), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "关于 WheelWise", action: #selector(aboutClicked), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "退出 WheelWise", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func toggleClicked() { onToggle?(!enabled) }
    @objc private func settingsClicked() { onOpenSettings?() }

    @objc private func aboutClicked() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [:])
    }

    @objc private func quitClicked() { NSApp.terminate(nil) }
}
