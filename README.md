# WheelWise

[![CI](https://github.com/Aaron48615/WheelWise/actions/workflows/ci.yml/badge.svg)](../../actions)
[![Release](https://img.shields.io/github/v/release/Aaron48615/WheelWise)](../../releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**让 macOS 鼠标滚轮的方向和网页滚动方向一致，同时完全不影响触控板。**

macOS 的「自然滚动」是全局设置：开启后触控板舒服了，但外接鼠标滚轮就反了——向下滚，页面却向上跑。WheelWise 只反转**鼠标滚轮**的事件方向，触控板保持系统原样。

中文说明在下面，English section at the bottom.

---

## 功能

- 🖱️ **只反转鼠标滚轮**：滚轮向下 → 页面向下滚动，方向与手上的动作一致
- 👆 **触控板零影响**：通过系统滚动事件的「连续/离散」特征区分设备，触控板（含惯性滚动）原样放行
- 🌊 **平滑滚动**：把滚轮"一格一格"的跳变变成连续顺滑的滚动，速度倍率可调
- ↔️ 可选反转水平滚轮方向
- 🚫 **忽略列表**：指定应用保持系统默认滚动行为
- 🍎 登录时自动启动（macOS 13+ SMAppService）
- 🧠 智能提示：检测到你已关闭系统「自然滚动」时会提醒（此时滚轮本来就是传统方向）

## 安装

### 下载 Release（推荐）

1. 到 [Releases](../../releases) 下载 `WheelWise-x.x.x.zip`
2. 解压，把 **WheelWise.app** 拖进「应用程序」
3. 首次打开（未公证的 ad-hoc 签名应用，任选其一）：
   - 在 Finder 中**右键点击 WheelWise.app → 打开 → 再点"打开"**；或
   - 终端执行：`xattr -cr /Applications/WheelWise.app`
4. 首次启动会弹出引导窗口 → 点「打开系统设置」→ 在 **隐私与安全性 → 辅助功能** 中勾选 WheelWise
5. 授权后窗口自动关闭，菜单栏出现鼠标图标即已生效

> **为什么需要辅助功能权限？** WheelWise 依靠系统事件接口（CGEventTap）拦截并改写滚轮事件，这是 macOS 对这类工具的标准权限要求。WheelWise 不收集任何数据，不上传任何信息，代码全部开源可审计。

### 从源码构建

```bash
git clone https://github.com/Aaron48615/WheelWise.git
cd WheelWise
bash scripts/build-app.sh          # 产物: build/WheelWise.app
open build/WheelWise.app
```

依赖：Swift 6 工具链（完整 Xcode，或 Swift.org 工具链）。无任何第三方依赖。

开发文档：[AGENTS.md](AGENTS.md)（构建/授权/避坑指南）、[docs/TECH-NOTES.md](docs/TECH-NOTES.md)（滚动事件技术细节）、[docs/ROADMAP.md](docs/ROADMAP.md)（路线图）、[CHANGELOG.md](CHANGELOG.md)（迭代记录）。

跑测试：

```bash
swift test    # 完整 Xcode 环境直接可用
# 仅 Command Line Tools（无 XCTest）时，用 Swift Testing 框架路径:
FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test -Xswiftc -F -Xswiftc $FW -Xlinker -rpath -Xlinker $FW -Xlinker -rpath -Xlinker $LIB
```

## 工作原理

macOS 会给滚动事件打上"来源"标记：

| 事件类型 | `kCGScrollWheelEventIsContinuous` | 来源 |
|---|---|---|
| 离散滚动 | 0 | 滚轮鼠标 |
| 连续滚动 | 1 | 触控板 / 力控触面 |

WheelWise 在系统 HID 层注册一个 `CGEventTap`（只监听滚轮事件）：

- **连续事件**（触控板）→ 原样放行，一个字节都不动
- **离散事件**（滚轮）→ 把垂直轴的「行数 / 像素 / 定点」三种增量字段同时取负后放行（开启平滑滚动时则吞掉原始事件，改由 120Hz 定时器发出带缓动曲线的连续滚动事件）

## 常见问题

**Q: 辅助功能列表里找不到 WheelWise，或手动添加了也不生效？**
先退出 WheelWise，执行下面命令清掉可能过期的授权记录，再重新打开应用，用系统弹出的原生授权对话框授权：

```bash
tccutil reset Accessibility com.wheelwise.WheelWise
open /Applications/WheelWise.app
```

**Q: 重新构建/更新后又要重新授权？**
ad-hoc 签名的应用每次重新构建，签名都会变化，macOS 会视为新应用。这是开发期现象；正式签名（Developer ID）后不会再发生。

**Q: 触控板滚动会受影响吗？**
不会。判定依据是事件本身的「连续/离散」标记，触控板事件完全不会被触碰。

**Q: 和 Logitech Options+ / 罗技、雷蛇等驱动冲突吗？**
建议关闭这类驱动软件里的"平滑滚动/智能滚动"接管功能，避免两层处理叠加。若某应用表现异常，把它加入 WheelWise 的忽略列表。

**Q: Magic Mouse（妙控鼠标）？**
它的滚动是触摸式的，默认和触控板一样保持系统行为。想反转它请打开设置里的「同时反转 Magic Mouse（实验性）」。

**Q: 应用是未公证的，安全吗？**
当前版本使用 ad-hoc 签名（作者暂无 Apple 开发者账号）。代码完全开源，你也可以自己从源码构建。拿到开发者账号后会加入公证。

## Roadmap

- [ ] 自定义平滑滚动曲线 / 步长
- [ ] 每应用独立配置
- [ ] Developer ID 签名 + 公证分发

## License

[MIT](LICENSE)。本项目借鉴了 Scroll Reverser / Mos / UnnaturalScrollWheels 的公开思路，代码全部独立实现，未复制任何 GPL 代码。

---

# WheelWise (English)

Make your **mouse wheel scroll in the direction you turn it**, without touching the trackpad's natural scrolling.

## Why

macOS "Natural scrolling" is a global toggle — comfortable for trackpads, backwards for mouse wheels. WheelWise reverses **only mouse wheel events** at the HID level and leaves continuous (trackpad) events untouched.

## Install

Download from [Releases](../../releases), drag to `/Applications`, then:

```bash
xattr -cr /Applications/WheelWise.app   # unsigned ad-hoc build
open /Applications/WheelWise.app
```

Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility). Requires macOS 13+.

## How it works

A `CGEventTap` listens for scroll-wheel events. Continuous events (trackpad, `kCGScrollWheelEventIsContinuous == 1`) pass through untouched; discrete events (wheel mouse) get their line/pixel/fixed-point delta fields negated, or are replaced by eased synthetic continuous events when smooth scrolling is enabled.

## Build

```bash
swift build && swift test
bash scripts/build-app.sh   # → build/WheelWise.app (ad-hoc signed)
```

Developer docs: [AGENTS.md](AGENTS.md) (build/permission/gotchas), [docs/TECH-NOTES.md](docs/TECH-NOTES.md) (scroll-event internals), [docs/ROADMAP.md](docs/ROADMAP.md), [CHANGELOG.md](CHANGELOG.md).

## License

MIT.
