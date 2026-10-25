import Foundation
import Network

/// Serves the debug viewer page over HTTP on loopback. Its origin is the only browser origin the channel allows.
final class PlaygroundDebugViewer: @unchecked Sendable {
    private let requestedPort: UInt16
    private let queue = DispatchQueue(label: "nsassets.playground.debug-viewer")
    private var listener: NWListener?

    /// `port` 0 picks a free port.
    init(port: UInt16 = 0) {
        self.requestedPort = port
    }

    static func origin(port: UInt16) -> String {
        "http://127.0.0.1:\(port)"
    }

    /// Starts serving a page that connects to the channel on `webSocketPort` with `token`, and returns the HTTP port.
    func start(webSocketPort: UInt16, token: String) async throws -> UInt16 {
        let page = PlaygroundDebugViewerPage.html(webSocketPort: webSocketPort, token: token)
        let listener = try LoopbackListener.make(port: requestedPort)
        listener.newConnectionHandler = { [weak self] connection in self?.serve(page: page, on: connection) }
        queue.async { [self] in self.listener = listener }
        return try await LoopbackListener.start(listener, on: queue)
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
