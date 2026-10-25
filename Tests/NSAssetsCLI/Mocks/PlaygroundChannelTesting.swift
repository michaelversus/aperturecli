import Foundation
@testable import NSAssetsCLI

/// Shared helpers for tests that talk to a `PlaygroundChannelServer` over a real localhost socket.
protocol PlaygroundChannelTesting {}

extension PlaygroundChannelTesting {
    var token: String { "secret-token" }

    func makeSession(frames: [SimulatorFrame] = []) -> MockSimulatorSession {
        MockSimulatorSession(probeResult: supportedProbe, framesToEmit: frames)
    }

    func makeServer(
        session: MockSimulatorSession? = nil,
        verifier: SimulatorTapVerifier? = nil,
        output: @escaping @Sendable (String) -> Void = { _ in },
        handshakeTimeout: Duration = .seconds(5),
        componentPresenter: (any PlaygroundComponentPresenting)? = nil
    ) async throws -> (PlaygroundChannelServer, UInt16) {
        let server = PlaygroundChannelServer(
            session: session ?? makeSession(),
            token: token,
            verifier: verifier,
            componentPresenter: componentPresenter,
            output: output,
            port: 0,
            handshakeTimeout: handshakeTimeout
        )
        return (server, try await server.start())
    }

    func connect(port: UInt16, token: String?, origin: String? = nil) -> URLSessionWebSocketTask {
        var request = URLRequest(url: URL(string: "ws://127.0.0.1:\(port)")!)
        if let token {
            request.setValue(PlaygroundChannel.subprotocol(token: token), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        }
        if let origin { request.setValue(origin, forHTTPHeaderField: "Origin") }
        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()
        return task
    }

    /// Connects, reads the server hello and answers with a compatible hello.
    func handshake(port: UInt16) async throws -> URLSessionWebSocketTask {
        let client = connect(port: port, token: token)
        _ = try await receiveMessage(from: client)
        let hello = #"{"type":"hello","protocolVersion":\#(PlaygroundChannel.protocolVersion)}"#
        try await client.send(.string(hello))
        return client
    }

    func receiveMessage(from client: URLSessionWebSocketTask) async throws -> PlaygroundServerMessage {
        guard case let .string(text) = try await client.receive() else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try JSONDecoder().decode(PlaygroundServerMessage.self, from: Data(text.utf8))
    }

    func componentRequestJSON(id: String) -> String {
        """
        {"type":"showComponent","id":"\(id)","kind":"swiftUIView","source":"import SwiftUI",
         "entry":"A()","snapshotName":"populated","theme":"dark"}
        """
    }

    func receiveStatus(from client: URLSessionWebSocketTask) async throws -> PlaygroundComponentStatus {
        guard case let .string(text) = try await client.receive() else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try JSONDecoder().decode(PlaygroundComponentStatus.self, from: Data(text.utf8))
    }

    var supportedProbe: SimulatorProbeResult {
        SimulatorProbeResult(status: .supported, xcodeVersion: "27.1", coreSimulatorVersion: "1155.4", issues: [])
    }
}
