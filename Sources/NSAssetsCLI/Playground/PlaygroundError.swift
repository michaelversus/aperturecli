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
}
