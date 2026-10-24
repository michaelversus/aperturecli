/// The per-contact phases of the digitizer model: a gesture is `start`, any `position`s, then `end`.
enum SimulatorTouchPhase: UInt64, Sendable {
    case start = 0
    case position = 1
    case end = 2
}
