import ServiceManagement

/// 开机自启（macOS 13+ SMAppService）。未打包成 .app 直接运行时注册会失败，由调用方兜底。
enum AutoLaunch {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
