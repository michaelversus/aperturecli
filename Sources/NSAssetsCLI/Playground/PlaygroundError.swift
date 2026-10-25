import Foundation

enum PlaygroundError: Error, Equatable {
    case unsupported
    case sessionNotStarted
    case symbolMissing(String)
    case serviceContextUnavailable(String)
    case deviceNotFound(String)
    case deviceNotBooted(String)
    case serviceLookupFailed(service: String, reason: String)
    case connectionFailed(service: String)
    case hidDaemonUnresponsive(attempts: Int)
    case commandFailed(String)
    case randomBytesUnavailable
    case unsupportedPlatform(String)
}

extension PlaygroundError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupported:
            "This machine cannot run the playground; see the probe output above."
        case .sessionNotStarted:
            "The simulator session has not been started."
        case let .symbolMissing(name):
            "A private symbol the playground needs is missing: \(name)."
        case let .serviceContextUnavailable(reason):
            "CoreSimulator could not be reached: \(reason)."
        case let .deviceNotFound(udid):
            "No simulator with UDID \(udid) was found."
        case let .deviceNotBooted(udid):
            "Simulator \(udid) is not booted. Boot it first, for example `xcrun simctl boot \(udid)`."
        case let .serviceLookupFailed(service, reason):
            "Could not look up \(service) in the simulator: \(reason)."
        case let .connectionFailed(service):
            "Could not connect to \(service)."
        case let .hidDaemonUnresponsive(attempts):
            "The simulator's HID daemon did not answer after \(attempts) attempts."
        case let .commandFailed(message):
            message
        case let .unsupportedPlatform(runtime):
            "The playground only supports iOS simulators, but this one runs \(runtime)."
        case .randomBytesUnavailable:
            "The system could not provide random bytes for the playground token."
        }
    }
}
