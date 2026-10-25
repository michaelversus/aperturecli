import Testing
@testable import NSAssetsCLI

struct SimulatorHomeGestureTests {
    @Test
    func itStartsAtTheBottomEdgeAndSweepsUpTheMiddleOfTheScreen() throws {
        let steps = SimulatorHomeGesture.steps

        #expect(steps.first?.phase == .start)
        #expect(steps.last?.phase == .end)
        #expect(steps.dropFirst().dropLast().allSatisfy { $0.phase == .position })
        #expect(try #require(steps.first).point.vertical > 0.99)
        #expect(try #require(steps.last).point.vertical < 0.6)
        #expect(steps.allSatisfy { $0.point.horizontal == 0.5 })
    }

    @Test
    func everyStepMovesUpwards() {
        let verticals = SimulatorHomeGesture.steps.map(\.point.vertical)

        #expect(zip(verticals, verticals.dropFirst()).allSatisfy { $0 > $1 })
    }
}
