# Roadmap

按优先级大致排序，每项附实现思路。做完记得更新 CHANGELOG 并打 tag 发版。

## 近期

### 1. 忽略列表：扫描运行中的应用
- **现状**：选择器只扫 `/Applications`、`/System/Applications`、`~/Applications` 三个目录，装在别处的应用选不到（实例：ZCode 在 `~/.zcode/computer-use/`，bundle id `dev.zcode.cua-helper`，用户只能手动输入）
- **做法**：`SettingsModel.scanInstalledApps()` 增加数据源 `NSWorkspace.shared.runningApplications`（过滤 `bundleIdentifier != nil` 且非辅助进程），与目录扫描合并去重；运行中的应用标个"运行中"徽标更好

### 2. 终端类应用平滑滚动反馈回收
- **现状**：v0.1.3 给合成事件补了 line/fixed 增量，用户尚未明确确认终端是否恢复
- **若无效果**：做一个带监听 tap 的调试构建，dump 终端实际收到的事件字段，确认 AppKit 读的是哪个；备选方案 `CGEventPostToPid` 直投前台进程（Mos 方案，顺带彻底消除 tap 回环）

## 中期

### 3. 平滑滚动参数自定义
- 把 `SmoothScrollEngine` 的 `timeConstant`（55ms，"绵密↔干脆"）与 `pixelsPerLine`（36px，"一格滚多远"）暴露到设置：三档预设 + 自定义滑杆
- 注意：改默认值必须过真机手感；参数语义见 docs/TECH-NOTES.md 第 5/7 节（两套行换算别混淆）

### 4. 每应用独立配置
- `ignoredApps: [String]` 升级为 per-app 规则表：`bundle id → { 反转开关, 速度, 平滑开关 }`，数据结构 `[String: AppRule]`
- UI：忽略列表行点击进详情编辑
- 性能注意：tap 线程每个事件都要查配置——用加锁快照字典，别在回调里做字符串匹配以外的事

### 5. 应用图标
- 当前无自定义 icns（菜单栏用的 SF Symbol `computermouse` 模板图）
- 做法：画 1024px 主图 → `sips` 生成各尺寸 png → `iconutil` 打包 icns → `build-app.sh` 里放入 Resources 并在 Info.plist 加 `CFBundleIconFile`

## 远期

### 6. Developer ID 签名 + 公证
- 前置：Apple Developer 账号（$99/年）
- 做法：`build-app.sh` 换真签名（`codesign --options runtime -s "Developer ID Application: …"`）；启用 `scripts/notarize.sh`（notarytool + stapler，GitHub Secrets：APPLE_ID / APPLE_TEAM_ID / APPLE_APP_SPECIFIC_PASSWORD）
- 收益：用户下载即开，不再需要 `xattr -cr` / 右键打开；重建不再作废授权（csreq 锚定证书而非 CDHash）
- 注意：签名身份变更会让老用户重新授权一次

### 7. 多语言 UI
- UI 目前纯中文、README 双语。用 String Catalog（.xcstrings）补英文，SPM 里需要手动加 localize resources

### 8. Magic Mouse 判定精细化
- 现状：Magic Mouse 属连续事件，靠"实验开关"整体反转（开了会把触控板也反转）
- 可探索：区分 Magic Mouse 与触控板的事件特征（phase/momentum 组合模式、设备子类型字段），实现自动识别、免开关

### 9. 菜单栏快速预设
- 菜单栏直接切换「仅反转 / 反转+平滑」等预设组合，方便临时场景（如把鼠标借给别人）

## 搁置 / 已拒绝

- （暂无；在此记录被否决的想法和原因，避免重复讨论）
