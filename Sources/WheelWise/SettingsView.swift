import AppKit
import SwiftUI
import WheelWiseCore

struct SettingsView: View {
    var onEnabledChanged: () -> Void

    @AppStorage(WheelWiseSettings.Key.enabled) private var enabled = true
    @AppStorage(WheelWiseSettings.Key.reverseVertical) private var reverseVertical = true
    @AppStorage(WheelWiseSettings.Key.reverseHorizontal) private var reverseHorizontal = false
    @AppStorage(WheelWiseSettings.Key.smoothScrolling) private var smoothScrolling = false
    @AppStorage(WheelWiseSettings.Key.scrollSpeed) private var scrollSpeed = 1.0
    @AppStorage(WheelWiseSettings.Key.magicMouseMode) private var magicMouseMode = false

    @State private var ignoredApps: [String] = WheelWiseSettings().ignoredApps
    @State private var newAppID = ""
    @State private var launchAtLogin = AutoLaunch.isEnabled
    @State private var naturalScrolling = WheelWiseSettings.systemNaturalScrollingEnabled

    var body: some View {
        Form {
            Section("反转") {
                Toggle("启用 WheelWise", isOn: $enabled)
                    .onChange(of: enabled) { _ in onEnabledChanged() }
                Toggle("垂直方向（滚轮向下 → 页面向下）", isOn: $reverseVertical)
                Toggle("水平方向", isOn: $reverseHorizontal)
            }

            Section("平滑滚动（仅作用于鼠标滚轮）") {
                Toggle("把滚轮的“一格一格”变成连续滚动", isOn: $smoothScrolling)
                HStack {
                    Text("速度")
                    Slider(value: $scrollSpeed, in: 0.25...3, step: 0.05)
                    Text(String(format: "×%.2f", scrollSpeed))
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
            }

            Section("忽略的应用（前台为这些应用时保持系统默认滚动）") {
                ForEach(ignoredApps, id: \.self) { id in
                    HStack {
                        Text(id)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(id)
                        Spacer()
                        Button("移除") {
                            ignoredApps.removeAll { $0 == id }
                            saveIgnoredApps()
                        }
                    }
                }
                HStack {
                    TextField("输入 Bundle ID，如 com.apple.Safari", text: $newAppID)
                        .onSubmit(addAppID)
                    Button("添加") { addAppID() }
                }
                Button("添加当前前台应用") {
                    if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                       !ignoredApps.contains(id) {
                        ignoredApps.append(id)
                        saveIgnoredApps()
                    }
                }
            }

            Section("其他") {
                Toggle("登录时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            try AutoLaunch.setEnabled(newValue)
                        } catch {
                            launchAtLogin = AutoLaunch.isEnabled
                        }
                    }
                Toggle("同时反转 Magic Mouse（实验性）", isOn: $magicMouseMode)
            }

            if !naturalScrolling {
                Section {
                    Text("检测到你已关闭系统「自然滚动」：此时滚轮方向本来就是传统的，可以保持 WheelWise 关闭。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 600)
    }

    private func addAppID() {
        let id = newAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !ignoredApps.contains(id) else { return }
        ignoredApps.append(id)
        newAppID = ""
        saveIgnoredApps()
    }

    private func saveIgnoredApps() {
        WheelWiseSettings().ignoredApps = ignoredApps
    }
}
