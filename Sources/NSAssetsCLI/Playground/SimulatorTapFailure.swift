enum SimulatorTapFailure: Equatable, Sendable {
    case screenUnchanged
    case eventsDropped([String])
}
