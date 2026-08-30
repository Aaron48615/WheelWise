import CoreGraphics
import Testing

@testable import WheelWiseCore

struct ScrollEventTests {
    private func makeWheelEvent(line1: Int64 = 0, line2: Int64 = 0) -> CGEvent {
        CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: Int32(clamping: Int(line1)),
            wheel2: Int32(clamping: Int(line2)),
            wheel3: 0
        )!
    }

    @Test func discreteEventClassifiedAsWheel() {
        let event = makeWheelEvent(line1: -5)
        #expect(ScrollWheelEventIO.source(of: event) == .wheel)
    }

    @Test func continuousEventClassifiedAsSurface() {
        let event = makeWheelEvent(line1: -5)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        #expect(ScrollWheelEventIO.source(of: event) == .continuousSurface)
    }

    @Test func reverseVerticalNegatesOnlyAxis1() {
        let event = makeWheelEvent(line1: 5, line2: -3)
        // CG 会从 line 字段派生 point/fixed，先记录取负前的有效值
        let prePoint1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let preFixed1 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let prePoint2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        let preFixed2 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2)

        ScrollWheelEventIO.applyReverse(to: event, vertical: true, horizontal: false)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -5)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -prePoint1)
        #expect(event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1) == -preFixed1)
        // 水平轴不受垂直开关影响
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == -3)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == prePoint2)
        #expect(event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2) == preFixed2)
    }

    @Test func reverseHorizontalNegatesOnlyAxis2() {
        let event = makeWheelEvent(line1: 5, line2: -3)
        ScrollWheelEventIO.applyReverse(to: event, vertical: false, horizontal: true)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 5)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 3)
    }

    @Test func reverseWithNothingEnabledIsNoop() {
        let event = makeWheelEvent(line1: 5, line2: -3)
        ScrollWheelEventIO.applyReverse(to: event, vertical: false, horizontal: false)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 5)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == -3)
    }

    @Test func syntheticTagRoundtrip() {
        let event = makeWheelEvent(line1: 1)
        #expect(!ScrollWheelEventIO.isSynthetic(event))
        event.setIntegerValueField(.eventSourceUserData, value: ScrollWheelEventIO.syntheticTag)
        #expect(ScrollWheelEventIO.isSynthetic(event))
    }

    @Test func phaseRawValues() {
        // CG 滚动相位的真实编码（不是 NSEventPhase 位掩码！）：
        // began=1、changed=2、ended=4。写错编码的帧会被系统静默丢弃。
        #expect(SyntheticScrollPhase.began.publicRawValue == 1)
        #expect(SyntheticScrollPhase.changed.publicRawValue == 2)
        #expect(SyntheticScrollPhase.ended.publicRawValue == 4)
    }

    @Test func reverseBothAxesTogether() {
        let event = makeWheelEvent(line1: 5, line2: -3)
        ScrollWheelEventIO.applyReverse(to: event, vertical: true, horizontal: true)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -5)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 3)
    }

    /// 合成事件构造：像素增量必须原样保留（整数）、相位编码正确。
    @Test func syntheticBuilderPreservesPixelDeltas() {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        )!
        SyntheticScrollEventBuilder.apply(
            event,
            pixelsY: 5.6,
            pixelsX: -40.4,
            phase: .changed
        )

        #expect(event.getIntegerValueField(.scrollWheelEventIsContinuous) == 1)
        #expect(event.getIntegerValueField(.scrollWheelEventScrollPhase) == 2)
        #expect(event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 6)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == -40)
    }
}
