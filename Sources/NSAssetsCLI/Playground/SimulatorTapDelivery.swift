enum SimulatorTapDelivery: Equatable, Sendable {
    case delivered
    case notDelivered(SimulatorTapFailure)
}
