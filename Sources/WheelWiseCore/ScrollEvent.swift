import CoreGraphics
import Foundation

/// scrollWheel 事件的来源分类。
public enum ScrollSource: Equatable, Sendable {
    /// 传统离散滚轮（绝大多数外接鼠标）。
    case wheel
    /// 连续触摸式滚动（触控板、Magic Mouse 等力控触面）。
    case continuousSurface
}

/// 合成滚动事件的相位。
///
/// 注意：kCGScrollWheelEventScrollPhase 的编码**不是** NSEventPhase 的位掩码，
/// 而是：began=1、changed=2、ended=4（另有 8=取消、128=按住）；
/// momentum 相位才用 1/2/3。写错编码的事件帧会被系统静默丢弃
/// （实测表现：只有 began 帧生效，后续帧全部消失）。
public enum SyntheticScrollPhase: Equatable, Sendable {
    case began
    case changed
    case ended

    var cgRawValue: Int64 {
        switch self {
        case .began: return 1
        case .changed: return 2
        case .ended: return 4
        }
    }

    /// 供 App 层使用的公开访问器。
    public var publicRawValue: Int64 { cgRawValue }
}

/// 合成连续滚动事件的字段填充。
///
/// 字段策略：像素增量（point）给 Chromium 系（浏览器/VSCode）等按像素
/// 滚动的 App；行增量（line）与定点增量（fixed）给 AppKit/终端等按行
/// 滚动的 App——三者都写，缺谁谁失灵（终端缺 line/fixed 时完全不动）。
/// 折算采用系统惯例 1 行 = 10px。
///
/// 顺序必须按 line → point → fixed 写（写 line 会联动重算 point/fixed，
/// 该顺序已在真实 CG 语义下用单元测试验证可保留全部显式值）。
public enum SyntheticScrollEventBuilder {
    /// 行 → 像素的系统惯例换算系数。
    private static let pointsPerLine = 10.0

    public static func apply(
        _ event: CGEvent,
        pixelsY: Double,
        pixelsX: Double,
        phase: SyntheticScrollPhase
    ) {
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase.publicRawValue)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        fillAxis(
            event,
            pixels: pixelsY,
            line: .scrollWheelEventDeltaAxis1,
            point: .scrollWheelEventPointDeltaAxis1,
            fixed: .scrollWheelEventFixedPtDeltaAxis1
        )
        fillAxis(
            event,
            pixels: pixelsX,
            line: .scrollWheelEventDeltaAxis2,
            point: .scrollWheelEventPointDeltaAxis2,
            fixed: .scrollWheelEventFixedPtDeltaAxis2
        )
    }

    private static func fillAxis(
        _ event: CGEvent,
        pixels: Double,
        line: CGEventField,
        point: CGEventField,
        fixed: CGEventField
    ) {
        event.setIntegerValueField(line, value: Int64(pixels / pointsPerLine))
        event.setIntegerValueField(point, value: Int64(pixels.rounded()))
        event.setIntegerValueField(fixed, value: Int64(pixels / pointsPerLine * 65536))
    }
}

/// scrollWheel 事件字段的读写与改写。纯逻辑，便于单元测试。
///
/// 关键事实：触控板产生“连续”滚动事件（isContinuous = 1），
/// 滚轮鼠标产生“离散”事件（isContinuous = 0）——这是只影响鼠标、
/// 不影响触控板的判定依据。
public enum ScrollWheelEventIO {
    /// 写在合成事件上的标记。事件 tap 据此跳过自己发出的事件，
    /// 否则合成事件会再次进入 tap，被当成普通滚轮事件处理形成回环。
    public static let syntheticTag: Int64 = 0x57686536 // "Whe6"

    public static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticTag
    }

    public static func source(of event: CGEvent) -> ScrollSource {
        event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            ? .continuousSurface
            : .wheel
    }

    /// 反转事件轴。同一轴的“行 / 像素 / 定点”三种字段必须一起取负，
    /// 只翻其中一种会导致不同 App 表现不一致。
    ///
    /// 注意：CG 滚动事件的字段存在耦合——写 line 字段会连带重算
    /// point/fixed 字段。因此必须先把三个字段都读出来，再依次写回，
    /// 否则依赖字段会被“取负两次”而抵消。
    public static func applyReverse(to event: CGEvent, vertical: Bool, horizontal: Bool) {
        if vertical { negateAxis1(on: event) }
        if horizontal { negateAxis2(on: event) }
    }

    public static func negateAxis1(on event: CGEvent) {
        negate(
            on: event,
            line: .scrollWheelEventDeltaAxis1,
            point: .scrollWheelEventPointDeltaAxis1,
            fixed: .scrollWheelEventFixedPtDeltaAxis1
        )
    }

    public static func negateAxis2(on event: CGEvent) {
        negate(
            on: event,
            line: .scrollWheelEventDeltaAxis2,
            point: .scrollWheelEventPointDeltaAxis2,
            fixed: .scrollWheelEventFixedPtDeltaAxis2
        )
    }

    private static func negate(on event: CGEvent, line: CGEventField, point: CGEventField, fixed: CGEventField) {
        // 先全部读出（此时 getter 会按耦合语义给出当前有效值）
        let lineValue = event.getIntegerValueField(line)
        let pointValue = event.getIntegerValueField(point)
        let fixedValue = event.getIntegerValueField(fixed)
        // 再写回：line 先写（会触发 CG 重算 point/fixed），随后用显式值覆盖
        event.setIntegerValueField(line, value: -lineValue)
        event.setIntegerValueField(point, value: -pointValue)
        event.setIntegerValueField(fixed, value: -fixedValue)
    }
}
