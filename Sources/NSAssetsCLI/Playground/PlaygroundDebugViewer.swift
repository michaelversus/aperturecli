import Foundation
import Network

/// Serves the debug viewer page over HTTP on loopback. Its origin is the only browser origin the channel allows.
final class PlaygroundDebugViewer: @unchecked Sendable {
    /// Set from the listener's state handler, which runs on the viewer's serial queue.
    private final class OnceFlag: @unchecked Sendable {
        var isSet = false
    }

    private let requestedPort: UInt16
    private let queue = DispatchQueue(label: "nsassets.playground.debug-viewer")
    private var listener: NWListener?

    init(httpPort: UInt16 = 8787) {
        self.requestedPort = httpPort
    }

    static func origin(port: UInt16) -> String {
        "http://127.0.0.1:\(port)"
    }

    /// Starts serving a page that connects to the channel on `webSocketPort` with `token`, and returns the HTTP port.
    func start(webSocketPort: UInt16, token: String) async throws -> UInt16 {
        let page = PlaygroundDebugViewerPage.html(webSocketPort: webSocketPort, token: token)
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: requestedPort) ?? .any
        )
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.serve(page: page, on: connection) }
        return try await bind(listener)
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                listener?.cancel()
                listener = nil
                continuation.resume()
            }
        }
    }

    private func bind(_ listener: NWListener) async throws -> UInt16 {
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
            queue.async { [self] in self.listener = listener }
        }
    }

    private func serve(page: String, on connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { _, _, _, _ in
            let body = Data(page.utf8)
            let head = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n"
                + "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
