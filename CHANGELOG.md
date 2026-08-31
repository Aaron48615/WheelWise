# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/)。

## [Unreleased]

### 计划中
- 忽略列表选择器改扫运行中的应用（覆盖非标准安装位置的应用，详见 docs/ROADMAP.md）
- 终端类应用平滑滚动的实测反馈回收；若无效，备选方案 CGEventPostToPid 直投目标进程

## [0.1.3] - 2026-08-31

### 修复
- 平滑滚动在终端类应用（AppKit 系）完全不动：合成事件只写了像素增量，而 AppKit 按 line/fixed 行增量滚动。现在三路增量都写（行折算 10px/行），按 line → point → fixed 顺序写入避开 CG 字段联动

### 改进
- 忽略列表：「添加前台应用」改为**打开设置时**快照（原来点按钮时前台已是 WheelWise 自己，永远加错）；新增"从已安装应用中添加"选择菜单（扫描 /Applications、/System/Applications、~/Applications）；列表显示应用名 + Bundle ID 双行
- 水平滚轮反转标注「实验性」

## [0.1.2] - 2026-08-31

### 修复
- **平滑滚动相位编码错误**：`kCGScrollWheelEventScrollPhase` 实际编码是 began=1 / changed=2 / ended=4（不是 NSEventPhase 位掩码 1/4/8），错误帧被系统静默丢弃——症状为每格只滚几像素、快速滚动纹丝不动
- 平滑路径漏掉方向取负（方向回到系统默认）
- 合成事件 point 增量字段内部是整数，Double 小数写入被截断

### 改进
- 辅助功能授权改走系统原生弹窗（`AXIsProcessTrustedWithOptions(prompt:)`），应用自动注册进辅助功能列表，不再依赖手动添加

## [0.1.1] - 2026-08-30

### 修复
- 平滑滚动发出全零事件（页面完全不动）：CG 写 line 字段会联动重算 point/fixed，旧代码先构造像素事件再写 line（120Hz 下折算恒为 0），像素增量被清零。字段填充抽入 `SyntheticScrollEventBuilder`，按已验证顺序写入

### 变更
- 首个通过 CI 自动发布双架构 zip 的版本

## [0.1.0] - 2026-08-30

- 首个版本：CGEventTap 反转滚轮方向、触控板直通（isContinuous 判定）、菜单栏开关、SwiftUI 设置窗口、忽略列表、开机自启（SMAppService）、Magic Mouse 实验开关、15 个 Swift Testing 测试、CI/Release 流水线
