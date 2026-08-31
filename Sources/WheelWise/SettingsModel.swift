import AppKit
import WheelWiseCore

struct InstalledApp: Identifiable, Equatable {
    let name: String
    let bundleID: String
    var id: String { bundleID }
}

/// 设置窗口的数据模型：忽略列表、已安装应用扫描、前台应用快照。
/// 全部在主线程访问。
final class SettingsModel: ObservableObject {
    @Published var ignoredApps: [String]
    @Published var newAppID = ""
    @Published var installedApps: [InstalledApp] = []
    /// 打开设置窗口那一刻的前台应用——通常就是用户刚发现滚动问题的应用。
    /// 若那一刻前台是 WheelWise 自己则为 nil。
    @Published var previousApp: InstalledApp?

    private let settings = WheelWiseSettings()
    private let ownBundleID = Bundle.main.bundleIdentifier ?? "com.wheelwise.WheelWise"

    init() {
        ignoredApps = settings.ignoredApps
        scanInstalledApps()
    }

    /// 在设置窗口即将展示前调用（此时前台还是用户之前的应用）。
    func refreshPreviousApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier,
              id != ownBundleID else {
            previousApp = nil
            return
        }
        previousApp = InstalledApp(name: app.localizedName ?? id, bundleID: id)
    }

    func add(_ rawID: String) {
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !ignoredApps.contains(id) else { return }
        ignoredApps.append(id)
        settings.ignoredApps = ignoredApps
    }

    func remove(_ id: String) {
        ignoredApps.removeAll { $0 == id }
        settings.ignoredApps = ignoredApps
    }

    /// Bundle ID → 应用显示名；查不到就原样显示 ID。
    func displayName(for bundleID: String) -> String {
        if let app = installedApps.first(where: { $0.bundleID == bundleID }) {
            return app.name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }

    /// 扫描常见应用目录（后台线程），供“从已安装应用中添加”选择。
    private func scanInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var seen = Set<String>()
            var apps: [InstalledApp] = []
            let directories = [
                "/Applications",
                "/System/Applications",
                NSString(string: "~/Applications").expandingTildeInPath,
            ]
            for directory in directories {
                guard let items = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
                    continue
                }
                for item in items where item.hasSuffix(".app") {
                    let url = URL(fileURLWithPath: directory).appendingPathComponent(item)
                    guard let bundle = Bundle(url: url),
                          let id = bundle.bundleIdentifier,
                          !seen.contains(id) else { continue }
                    seen.insert(id)
                    let info = bundle.infoDictionary ?? [:]
                    let localized = bundle.localizedInfoDictionary ?? [:]
                    let name = (localized["CFBundleDisplayName"] as? String)
                        ?? (info["CFBundleDisplayName"] as? String)
                        ?? (localized["CFBundleName"] as? String)
                        ?? (info["CFBundleName"] as? String)
                        ?? url.deletingPathExtension().lastPathComponent
                    apps.append(InstalledApp(name: name, bundleID: id))
                }
            }
            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { [weak self] in
                self?.installedApps = apps
            }
        }
    }
}
