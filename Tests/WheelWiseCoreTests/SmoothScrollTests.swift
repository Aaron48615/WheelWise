import Testing

@testable import WheelWiseCore

struct SmoothScrollTests {
    private let pixelsPerLine = 36.0

    @Test func engineDrainsExactly() {
        var engine = SmoothScrollEngine(timeConstant: 0.05, pixelsPerLine: pixelsPerLine)
        engine.add(lines: 5)
        var total = 0.0
        var iterations = 0
        while !engine.isIdle {
            total += engine.tick(dt: 1.0 / 120.0) ?? 0
            iterations += 1
            #expect(iterations < 10_000, "引擎未收敛")
            if iterations >= 10_000 { break }
        }
        #expect(abs(total - 5 * pixelsPerLine) < 1.0)
        #expect(engine.tick(dt: 1.0 / 120.0) == nil, "排空后不应再有输出")
    }

    @Test func enginePreservesSign() {
        var engine = SmoothScrollEngine(timeConstant: 0.05, pixelsPerLine: pixelsPerLine)
        engine.add(lines: -2)
        var sawPositive = false
        var iterations = 0
        while !engine.isIdle {
            let delta = engine.tick(dt: 1.0 / 120.0) ?? 0
            if delta > 0 { sawPositive = true }
            iterations += 1
            #expect(iterations < 10_000)
            if iterations >= 10_000 { break }
        }
        #expect(!sawPositive)
    }

    @Test func controllerPhaseSequence() {
        let controller = SmoothScrollController(timeConstant: 0.05, pixelsPerLine: pixelsPerLine)
        controller.add(linesY: 3, linesX: 0)

        var emissions: [SmoothScrollController.Emission] = []
        var iterations = 0
        while !controller.isIdle {
            emissions.append(contentsOf: controller.tick(dt: 1.0 / 60.0))
            iterations += 1
            #expect(iterations < 5_000, "状态机未收敛")
            if iterations >= 5_000 { break }
        }

        #expect(emissions.first?.phase == .began)
        #expect(emissions.last?.phase == .ended)
        let middles = emissions.dropFirst().dropLast()
        #expect(!middles.isEmpty, "滚动量足够时应存在 changed 帧")
        #expect(middles.allSatisfy { $0.phase == .changed })
        // ended 帧增量为 0，总量由前面帧贡献
        #expect(emissions.last?.pixelsY == 0)
        let total = emissions.reduce(0.0) { $0 + $1.pixelsY }
        #expect(abs(total - 3 * pixelsPerLine) < 1.5)
    }

    @Test func newEventDuringAnimationExtendsTotal() {
        let controller = SmoothScrollController(timeConstant: 0.05, pixelsPerLine: pixelsPerLine)
        controller.add(linesY: 1, linesX: 0)
        // 第一帧的输出也要计入总量
        let firstBatch = controller.tick(dt: 1.0 / 60.0)
        var total = firstBatch.reduce(0.0) { $0 + $1.pixelsY }
        controller.add(linesY: 1, linesX: 0)

        var iterations = 0
        while !controller.isIdle {
            let batch = controller.tick(dt: 1.0 / 60.0)
            total += batch.reduce(0.0) { $0 + $1.pixelsY }
            iterations += 1
            #expect(iterations < 5_000)
            if iterations >= 5_000 { break }
        }
        #expect(abs(total - 2 * pixelsPerLine) < 2.0)
    }

    @Test func speedScalesOutput() {
        let slow = SmoothScrollController(timeConstant: 0.05, pixelsPerLine: pixelsPerLine)
        slow.speed = 0.5
        slow.add(linesY: 4, linesX: 0)
        var slowTotal = 0.0
        while !slow.isIdle {
            slowTotal += slow.tick(dt: 1.0 / 60.0).reduce(0.0) { $0 + $1.pixelsY }
        }

        let fast = SmoothScrollController(timeConstant: 0.05, pixelsPerLine: pixelsPerLine)
        fast.speed = 2.0
        fast.add(linesY: 4, linesX: 0)
        var fastTotal = 0.0
        while !fast.isIdle {
            fastTotal += fast.tick(dt: 1.0 / 60.0).reduce(0.0) { $0 + $1.pixelsY }
        }

        #expect(abs(slowTotal - 4 * pixelsPerLine * 0.5) < 2.0)
        #expect(abs(fastTotal - 4 * pixelsPerLine * 2.0) < 2.0)
    }

    @Test func idleControllerEmitsNothing() {
        let controller = SmoothScrollController()
        #expect(controller.tick(dt: 1.0 / 60.0).isEmpty)
        #expect(controller.isIdle)
    }
}
