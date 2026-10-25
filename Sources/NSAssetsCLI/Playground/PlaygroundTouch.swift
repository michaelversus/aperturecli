/// One contact of a gesture a client streams: where the finger is, and whether it just went down, moved or lifted.
struct PlaygroundTouch: Sendable, Equatable {
    let phase: SimulatorTouchPhase
    let point: NormalizedPoint
}
