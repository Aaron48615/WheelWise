// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WheelWise",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WheelWise", targets: ["WheelWise"])
    ],
    targets: [
        // C shim：Swift 无法直接调用的 CG API（如 CGEventTapEnable）。
        .target(name: "CWheelWiseShim", publicHeadersPath: "include"),
        // 纯逻辑层：事件字段读写、设备判定、平滑滚动数学。不依赖 AppKit，可单元测试。
        .target(name: "WheelWiseCore"),
        // 应用层：CGEventTap、菜单栏、设置界面。
        .executableTarget(
            name: "WheelWise",
            dependencies: ["CWheelWiseShim", "WheelWiseCore"],
            path: "Sources/WheelWise"
        ),
        .testTarget(
            name: "WheelWiseCoreTests",
            dependencies: ["WheelWiseCore"],
            path: "Tests/WheelWiseCoreTests"
        ),
    ],
    // 保持 Swift 5 语言模式（CGEventTap 回调代码不适合严格并发检查）
    swiftLanguageModes: [.v5]
)
