# AGENTS.md — AI 开发助手指南

WheelWise：macOS 菜单栏工具，反转**鼠标滚轮**方向（滚轮向下 = 页面向下），完全不影响触控板的自然滚动。纯系统 API（CGEventTap），零第三方依赖，MIT 协议。

> **改事件处理代码前必读 [docs/TECH-NOTES.md](docs/TECH-NOTES.md)**——里面的坑（字段联动、相位编码）在 Apple 文档里查不到，全部是实测踩出来的。

## 目录结构

| 路径 | 内容 |
|---|---|
| `Sources/WheelWiseCore` | 纯逻辑层：事件字段读写、设备判定、平滑滚动引擎、设置。不依赖 AppKit，**新逻辑尽量放这里**（可单元测试） |
| `Sources/WheelWise` | 应用层：CGEventTap 生命周期、菜单栏、SwiftUI 设置窗口、权限引导、开机自启 |
| `Sources/CWheelWiseShim` | C shim：Swift 无法直接调用的 CG API（`CGEventTapEnable` 被 obsoleted） |
| `Tests/WheelWiseCoreTests` | Swift Testing 测试（15 个） |
| `scripts/build-app.sh` | 打包 .app + ad-hoc 签名（`UNIVERSAL=1` 出双架构） |
| `scripts/notarize.sh` | 公证占位（取得 Developer ID 后启用） |
| `docs/TECH-NOTES.md` | CG 滚动事件深层技术细节 |
| `docs/ROADMAP.md` | 功能规划与实现思路 |
| `CHANGELOG.md` | 版本迭代记录 |

## 本机构建与测试（重要：本机无完整 Xcode，只有 Command Line Tools）

- 测试框架是 **Swift Testing**（`import Testing`），**没有 XCTest**
- `swift test` 必须带框架路径参数，否则找不到 Testing 模块：

```bash
FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test -Xswiftc -F -Xswiftc $FW -Xlinker -rpath -Xlinker $FW -Xlinker -rpath -Xlinker $LIB
```

- `swift build -c release` 正常；打包 `bash scripts/build-app.sh`
- `Package.swift` 是 tools 6.0 + `swiftLanguageModes: [.v5]`（CGEventTap 回调代码不适合严格并发检查）

## 重建后必须重走授权（ad-hoc 签名的宿命）

每次 `swift build`/`build-app.sh` 都会改变二进制签名，TCC 授权随之失效——设置里开关可能显示"已打开"但实际校验不过（幽灵记录）。标准流程：

```bash
pkill -x WheelWise
tccutil reset Accessibility com.wheelwise.WheelWise
open build/WheelWise.app   # → 系统原生弹窗 → 授权
```

验证授权真生效（tap 线程存在 = 真的能用）：

```bash
sample $(pgrep -x WheelWise) 1 | grep eventtap   # 应看到 com.wheelwise.eventtap
```

## 发布流程

1. 更新 `scripts/build-app.sh` 里的 `APP_VERSION` 默认值 + `CHANGELOG.md`
2. commit + push main（CI 自动 build + test）
3. `git tag -a vX.Y.Z && git push origin vX.Y.Z` → Release workflow 自动构建双架构 zip 挂到 GitHub Releases
4. CI runner 必须是 **macos-15**（macos-14 镜像的 Xcode 不认 tools 6.0 manifest，Build 步骤 3 秒失败）

## 代码约定

- UI 文案中文；README 中英双语
- 设置项 key 统一在 `WheelWiseSettings.Key`；新设置走 UserDefaults（线程安全，tap 线程直接读）
- 事件 tap 回调在专用线程、UI 在主线程；跨线程共享状态必须加锁（参考 `ScrollTap` / `SmoothScrollController`）
- 纯计算放 WheelWiseCore 并配测试；应用层只做粘合
- 不引入第三方依赖；不复制 GPL 项目（Scroll Reverser/Mos/UnnaturalScrollWheels）的代码，只借鉴公开知识
