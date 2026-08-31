import AppKit
import SwiftUI
import WheelWiseCore

struct SettingsView: View {
    var onEnabledChanged: () -> Void
    @ObservedObject var model: SettingsModel

    @AppStorage(WheelWiseSettings.Key.enabled) private var enabled = true
    @AppStorage(WheelWiseSettings.Key.reverseVertical) private var reverseVertical = true
    @AppStorage(WheelWiseSettings.Key.reverseHorizontal) private var reverseHorizontal = false
    @AppStorage(WheelWiseSettings.Key.smoothScrolling) private var smoothScrolling = false
    @AppStorage(WheelWiseSettings.Key.scrollSpeed) private var scrollSpeed = 1.0
    @AppStorage(WheelWiseSettings.Key.magicMouseMode) private var magicMouseMode = false

    @State private var launchAtLogin = AutoLaunch.isEnabled
    @State private var naturalScrolling = WheelWiseSettings.systemNaturalScrollingEnabled

    var body: some View {
        Form {
            Section("反转") {
                Toggle("启用 WheelWise", isOn: $enabled)
                    .onChange(of: enabled) { _ in onEnabledChanged() }
                Toggle("垂直方向（滚轮向下 → 页面向下）", isOn: $reverseVertical)
                Toggle("水平方向（实验性）", isOn: $reverseHorizontal)
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
                if model.ignoredApps.isEmpty {
                    Text("暂无。哪个应用里滚动表现不合适，就把它加进来。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.ignoredApps, id: \.self) { id in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName(for: id))
                                .lineLimit(1)
                            Text(id)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("移除") { model.remove(id) }
                    }
                }
                Menu {
                    ForEach(model.installedApps) { app in
                        Button(app.name) { model.add(app.bundleID) }
                    }
                } label: {
                    Text(model.installedApps.isEmpty ? "正在读取已安装应用…" : "从已安装应用中添加…")
                }
                if let previous = model.previousApp {
                    Button("添加刚才的前台应用（\(previous.name)）") {
                        model.add(previous.bundleID)
                    }
                }
                HStack {
                    TextField("手动输入 Bundle ID，如 com.apple.Terminal", text: $model.newAppID)
                        .onSubmit(addTyped)
                    Button("添加") { addTyped() }
                }
                Text("提示：不知道 Bundle ID 就用上面两个按钮。「刚才的前台应用」指你打开本设置窗口之前正在使用的应用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        .frame(width: 460, height: 680)
    }

    private func addTyped() {
        model.add(model.newAppID)
        model.newAppID = ""
    }
}
