enum SimulatorProbeIssue: Sendable, Equatable {
    case coreSimulatorNotFound
    case simulatorKitNotFound
    case privateClassMissing(String)
    case xpcSymbolsMissing
    case coreSimulatorTooOld(minimum: String)
    case noFramebufferPort
    case surfaceSizeMismatch
    case multipleDisplays
    /// Repair resets the flag and restarts backboardd, which kills running apps; it is printed, never run.
    case deviceHubAttached(repairCommand: String)

    /// A blocking issue means the playground cannot work at all; anything else is a caveat.
    var isBlocking: Bool {
        switch self {
        case .coreSimulatorNotFound,
             .simulatorKitNotFound,
             .privateClassMissing,
             .xpcSymbolsMissing,
             .coreSimulatorTooOld,
             .noFramebufferPort:
            true
        case .surfaceSizeMismatch,
             .multipleDisplays,
             .deviceHubAttached:
            false
        }
    }
}

extension SimulatorProbeIssue {
    var message: String {
        switch self {
        case .coreSimulatorNotFound:
            "CoreSimulator framework not found."
        case .simulatorKitNotFound:
            "SimulatorKit framework not found, frames cannot be captured."
        case let .privateClassMissing(name):
            "The private class \(name) is missing, so this Xcode is not compatible."
        case .xpcSymbolsMissing:
            "Private libxpc symbols for the DTUHID connection are missing, input cannot be sent."
        case let .coreSimulatorTooOld(minimum):
            "CoreSimulator is older than \(minimum), which does not ship the DTUHID daemon."
        case .noFramebufferPort:
            "The simulator exposes no framebuffer display port."
        case .surfaceSizeMismatch:
            "No framebuffer surface matches the device's native size."
        case .multipleDisplays:
            "The device has multiple displays, input is routed to the main one only."
        case let .deviceHubAttached(repairCommand):
            "Device Hub is attached. Repair (not run, it kills running apps): \(repairCommand)"
        }
    }
}
