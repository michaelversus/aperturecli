extension SimulatorTapDelivery {
    var summary: String {
        switch self {
        case .delivered:
            "Tap delivered: the screen changed and no events were dropped."
        case .notDelivered(.screenUnchanged):
            "Tap NOT delivered: the screen did not change."
        case let .notDelivered(.eventsDropped(lines)):
            "Tap NOT delivered: the guest dropped events.\n" + lines.map { "  \($0)" }.joined(separator: "\n")
        }
    }
}
