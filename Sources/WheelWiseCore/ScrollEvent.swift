import CoreGraphics
import Foundation

/// scrollWheel 事件的来源分类。
public enum ScrollSource: Equatable, Sendable {
    /// 传统离散滚轮（绝大多数外接鼠标）。
    case wheel
    /// 连续触摸式滚动（触控板、Magic Mouse 等力控触面）。
    case continuousSurface
}

/// 合成滚动事件的相位。位值与 NSEventPhase 一致
/// （kCGScrollWheelEventScrollPhase 使用同一套位编码）。
public enum SyntheticScrollPhase: Equatable, Sendable {
    case began
    case changed
    case ended

    var cgRawValue: Int64 {
        switch self {
        case .began: return 0x1
        case .changed: return 0x4
        case .ended: return 0x8
        }
    }

    /// 供 App 层使用的公开访问器。
    public var publicRawValue: Int64 { cgRawValue }
}

/// 合成连续滚动事件的字段填充。
///
/// 关键坑（与反转路径同源）：CG 滚动事件的增量字段存在耦合，
/// 写 line 字段会联动重算 point/fixed 字段。因此每个轴必须按
/// line → point → fixed 的顺序写入（该顺序在真实 CG 语义下由
/// 单元测试验证），否则像素增量会被联动清零，表现为页面完全不动。
public enum SyntheticScrollEventBuilder {
    public static func apply(
        _ event: CGEvent,
        pixelsY: Double,
        pixelsX: Double,
        pixelsPerLine: Double,
        phase: SyntheticScrollPhase
    ) {
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase.publicRawValue)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)

        fillAxis(
            event,
            pixels: pixelsY,
            pixelsPerLine: pixelsPerLine,
            line: .scrollWheelEventDeltaAxis1,
            point: .scrollWheelEventPointDeltaAxis1,
            fixed: .scrollWheelEventFixedPtDeltaAxis1
        )
        fillAxis(
            event,
            pixels: pixelsX,
            pixelsPerLine: pixelsPerLine,
            line: .scrollWheelEventDeltaAxis2,
            point: .scrollWheelEventPointDeltaAxis2,
            fixed: .scrollWheelEventFixedPtDeltaAxis2
        )
    }

    private static func fillAxis(
        _ event: CGEvent,
        pixels: Double,
        pixelsPerLine: Double,
        line: CGEventField,
        point: CGEventField,
        fixed: CGEventField
    ) {
        let lineValue = Int64(pixels / pixelsPerLine)
        let pointValue = Int64(pixels.rounded())
        let fixedValue = Int64(pixels / pixelsPerLine * 65536)
        event.setIntegerValueField(line, value: lineValue)
        event.setIntegerValueField(point, value: pointValue)
        event.setIntegerValueField(fixed, value: fixedValue)
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
