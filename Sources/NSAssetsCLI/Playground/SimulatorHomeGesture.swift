/// The swipe up from the bottom edge that goes to the home screen on devices without a home button.
enum SimulatorHomeGesture {
    /// The digitizer's edge flag for the bottom edge, found by trying values against a simulator.
    static let bottomEdge: UInt64 = 3
    static let stepInterval = Duration.milliseconds(16)

    private static let stepCount = 20
    private static let startVertical = 0.995
    private static let endVertical = 0.5

    static let steps: [PlaygroundTouch] = (0...stepCount).map { step in
        let progress = Double(step) / Double(stepCount)
        let phase: SimulatorTouchPhase = switch step {
        case 0: .start
        case stepCount: .end
        default: .position
        }
        return PlaygroundTouch(
            phase: phase,
            point: NormalizedPoint(horizontal: 0.5, vertical: startVertical + (endVertical - startVertical) * progress)
        )
    }
}
