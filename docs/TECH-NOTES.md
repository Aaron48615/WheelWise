# 技术笔记 — macOS 滚动事件与 WheelWise 实现细节

写给未来的维护者（人类或 AI）。这些知识全部来自实测踩坑，部分行为在 Apple 文档里查不到、甚至与直觉相悖。改事件处理代码前请通读。

## 1. 鼠标 vs 触控板的判定

- 触控板/力控触面（含 Magic Mouse）产生**连续**滚动事件：`kCGScrollWheelEventIsContinuous = 1`
- 滚轮鼠标产生**离散**事件：`= 0`
- WheelWise 只处理离散事件（Magic Mouse 实验模式除外），连续事件原样放行——这是"不影响触控板"的根本依据

## 2. 增量字段与字段联动（最大的坑）

同一滚动轴有三个增量字段：

| 字段 | 含义 | 谁在读 |
|---|---|---|
| `DeltaAxis1/2` | 整数"行" | 终端等按行滚动的应用 |
| `PointDeltaAxis1/2` | 整数"像素" | Chromium 系（Chrome/VSCode）等按像素滚动的应用 |
| `FixedPtDeltaAxis1/2` | 16.16 定点"行"（带小数） | AppKit 系 |

实测行为（均有单元测试守护，见 `Tests/WheelWiseCoreTests/ScrollEventTests.swift`）：

1. **字段联动**：写 line 字段会联动重算 point/fixed。逐字段"边读边取负"会把 point/fixed 双重取负而抵消 → 部分应用方向反了、部分没反
2. **反转的正确写法**：先把三个字段都**读出来**，再按 **line → point → fixed** 顺序**写回**（该顺序的最终 readback 已实测验证全部正确；写 point/fixed 不会反向破坏 line）
3. **point 字段内部是整数**：`setDoubleValueField` 写 5.5 读回 5.0（截断）。小数部分只能进 fixed 字段
4. **不同应用读不同字段**：合成事件三路都要写，缺谁谁失灵（v0.1.3 前终端完全不滚，就是因为只写了 point）
5. 行↔像素换算：系统构造器实测 line=5 → point=40（8px/行）；写行字段采用惯例 **10px/行**

## 3. 相位编码（第二大的坑）

`kCGScrollWheelEventScrollPhase` 的编码**不是** NSEventPhase 的位掩码：

- began=**1**、changed=**2**、ended=**4**（另有 8=取消/离开、128=按住）
- `kCGScrollWheelEventMomentumPhase` 才是 0/1/2/3（none/begin/continue/end）
- 写错编码的事件帧被系统**静默丢弃**：实测只有 began（=1，恰好两种编码相同）帧生效，changed（误写 4=ended）帧全部消失
- 症状：每格只滚 ~5px、快速滚动几乎纹丝不动
- 依据：Mos（GPL 项目）公开的 PhaseValueMapping 表——**只借鉴了字段语义知识，未复制任何代码**（本项目 MIT，严禁引入 GPL 代码）

## 4. 合成平滑滚动事件配方

```swift
let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                    wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0)!
// 防回环标记：合成事件会再次进入自己的 tap，靠它跳过
event.setIntegerValueField(.eventSourceUserData, ScrollWheelEventIO.syntheticTag)
// 每轴按 line → point → fixed：
event.setIntegerValueField(.scrollWheelEventDeltaAxis1,        Int64(px / 10))
event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1,   Int64(px.rounded()))
event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, Int64(px / 10 * 65536))
// 相位（began=1 / changed=2 / ended=4）+ 动量 0 + isContinuous=1
event.post(tap: .cghidEventTap)
```

- 结束帧：全部增量为 0 + phase=ended
- 备选方案（未采用）：`CGEventPostToPid` 直投前台进程，可完全绕开 tap 链（Mos 的做法），若未来遇到 tap 回环/投递问题可切换

## 5. 平滑滚动引擎

- `SmoothScrollEngine`（单轴）：指数缓动。每帧输出 `remaining × (1 − e^(−dt/τ))`，τ=55ms；剩余量不足半像素时一步走完 → 总量精确收敛、不漂移
- 一格 = 1 line = **36px**（`pixelsPerLine`，产品参数：一格滚多远，与浏览器原生手感接近）
- `SmoothScrollController`（双轴状态机）：`add()` 由 tap 线程调用；`tick()` 由 120Hz DispatchSourceTimer 驱动（独立队列）；输出 began → changed… → ended 帧序列；**began 帧只在 空闲→活动 转换时发一次**（这也是相位编码 bug 的症状来源：changed 帧被丢后，快速滚动期间不再有新的 began）
- 方向：引擎吃"已按设置取负"的增量（平滑路径与反转路径的取负逻辑必须一致，v0.1.2 曾漏掉）

## 6. 权限（TCC）与事件 tap

- defaultTap（改写事件）需要**辅助功能**权限；用 `AXIsProcessTrusted()` 探测
- 首次引导**必须**调用 `AXIsProcessTrustedWithOptions(prompt: true)`——它会把应用自动注册进辅助功能列表；只做"跳转系统设置"的话，列表里根本不会出现本应用（v0.1.2 修过）
- ad-hoc 签名每次重建 CDHash 都变 → 旧授权变"幽灵"（设置里显示已开但校验不过）。重建后标准流程：`pkill` → `tccutil reset Accessibility com.wheelwise.WheelWise` → 重启走原生弹窗（详见 AGENTS.md）
- 验证 tap 真的活着：`sample <pid> 1 | grep eventtap`；创建失败时 App 会 NSLog「创建事件 tap 失败」
- TCC 列表可能不显示已生效的条目（显示怪癖），以 `AXIsProcessTrusted()` 返回值为准
- tap 会被系统禁用（超时/权限撤回）：App 每 1.5s 轮询，trusted → 重新 enable；untrusted → 重新引导

## 7. 已知怪癖 / 未解问题

- 忽略列表选择器只扫三个标准应用目录，装在别处的应用选不到（实例：ZCode 在 `~/.zcode/computer-use/`）。改进方向见 ROADMAP
- 终端滚动修复（v0.1.3）后的实际手感未获用户明确确认。若仍有问题：怀疑 AppKit 对合成连续事件 fixed/line 的读取路径，备选 `CGEventPostToPid`
- **两套行换算并存，别混淆**：36px/行 = "一格滚多远"的产品参数（引擎内）；10px/行 = 写 line/fixed 字段的系统惯例（builder 内）
- Logitech Options+ 等鼠标驱动可能双重处理滚轮事件，用户遇到怪现象先建议关闭其滚动接管

## 8. 测试

- Swift Testing（`import Testing`），不是 XCTest——本机无完整 Xcode，运行命令见 AGENTS.md
- 测试直接构造**真实 CGEvent** 验证字段读写（readback）——字段联动、整数截断、相位编码这三个问题只有这种方式能发现。改事件代码必须带 readback 测试
- CI（macos-15 runner）用完整 Xcode，直接 `swift test` 即可
