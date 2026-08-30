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
        #expect(SyntheticScrollPhase.began.publicRawValue == 0x1)
        #expect(SyntheticScrollPhase.changed.publicRawValue == 0x4)
        #expect(SyntheticScrollPhase.ended.publicRawValue == 0x8)
    }

    @Test func reverseBothAxesTogether() {
        let event = makeWheelEvent(line1: 5, line2: -3)
        ScrollWheelEventIO.applyReverse(to: event, vertical: true, horizontal: true)

        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -5)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 3)
    }

    /// 回归测试：写 line 字段会联动重算 point/fixed（CG 字段耦合）。
    /// 旧实现在合成事件上先写 line 再写 point，顺序错误导致像素增量
    /// 被清零，表现为开启平滑滚动后页面完全不动。
    @Test func syntheticBuilderPreservesPixelDeltas() {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        )!
        let pps = 36.0
        SyntheticScrollEventBuilder.apply(
            event,
            pixelsY: 5,
            pixelsX: 40,
            pixelsPerLine: pps,
            phase: .changed
        )

        #expect(event.getIntegerValueField(.scrollWheelEventIsContinuous) == 1)
        #expect(event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0x4)
        // 关键断言：像素增量不能被 line 字段的写入联动清零
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 5)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 0)
        #expect(event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1) == Int64(5.0 / pps * 65536))
        // 第二轴的写入不能破坏第一轴（跨轴耦合检查）
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 40)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 1)
        #expect(event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2) == Int64(40.0 / pps * 65536))
    }
}
