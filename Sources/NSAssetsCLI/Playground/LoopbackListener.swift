import Foundation
import Network

/// Creating and starting TCP listeners that accept connections from this machine only.
enum LoopbackListener {
    /// Set from the listener's state handler, which runs on the queue the listener starts on.
    private final class OnceFlag: @unchecked Sendable {
        var isSet = false
    }

    static func make(port: UInt16, webSocketOptions: NWProtocolWebSocket.Options? = nil) throws -> NWListener {
        let parameters = NWParameters.tcp
        if let webSocketOptions {
            parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)
        }
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port) ?? .any)
        return try NWListener(using: parameters)
    }

    /// Starts the listener on `queue` and returns the port it bound once it is ready.
    static func start(_ listener: NWListener, on queue: DispatchQueue) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            let finished = OnceFlag()
            listener.stateUpdateHandler = { state in
                guard !finished.isSet else { return }
                switch state {
                case .ready:
                    finished.isSet = true
                    continuation.resume(returning: listener.port?.rawValue ?? 0)
                case let .failed(error):
                    finished.isSet = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }
}
