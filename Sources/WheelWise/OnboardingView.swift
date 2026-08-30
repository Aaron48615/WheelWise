import SwiftUI
import WheelWiseCore

struct OnboardingView: View {
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("需要辅助功能权限", systemImage: "lock.shield")
                .font(.title3.bold())
            Text("WheelWise 通过系统事件接口改写鼠标滚轮的方向，因此需要辅助功能权限。")
            Text("系统可能已弹出「WheelWise 想要控制你的电脑」对话框。点「打开系统设置」，在「隐私与安全性 → 辅助功能」列表里找到 WheelWise 并打开开关。授权后本窗口会自动关闭，菜单栏出现鼠标图标即表示已生效。")
                .foregroundStyle(.secondary)
            Button("打开系统设置") { onOpenSettings() }
                .buttonStyle(.borderedProminent)
            Text("如果列表里没有 WheelWise，点列表下方的 + 按钮手动添加本应用，再打开开关。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if !WheelWiseSettings.systemNaturalScrollingEnabled {
                Text("提示：你已关闭系统的「自然滚动」，滚轮方向本来就是传统的，可能不需要 WheelWise。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 380, alignment: .leading)
    }
}
