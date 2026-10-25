/// A button of the simulated device that a client can press.
enum SimulatorHardwareButton: String, Sendable, Equatable {
    case home
    case lock
    case volumeUp
    case volumeDown

    /// The HID usage on the consumer page (0x0C) for a physical button. Home has none: devices without a home button
    /// ignore it, so the home screen is reached with `SimulatorHomeGesture`.
    var consumerUsage: UInt64? {
        switch self {
        case .home: nil
        case .lock: 0x30
        case .volumeUp: 0xE9
        case .volumeDown: 0xEA
        }
    }
}
