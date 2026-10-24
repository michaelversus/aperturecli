import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundChannelServerTests {
    private let token = "secret-token"
    private let frame = SimulatorFrame(
        jpegData: Data([0xFF, 0xD8, 0x01, 0x02]),
        widthInPixels: 10,
        heightInPixels: 20,
        timestamp: Date(timeIntervalSinceReferenceDate: 0),
        isReplay: false
    )

    @Test
    func aClientWithTheTokenReceivesTheServerHello() async throws {
        let (server, port) = try await makeServer()
        let client = connect(port: port, token: token)

        let hello = try await receiveMessage(from: client)

        #expect(hello.type == "hello")
        #expect(hello.protocolVersion == PlaygroundChannel.protocolVersion)
        #expect(hello.cliVersion == version)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aClientWithoutTheTokenIsRefused() async throws {
        let (server, port) = try await makeServer()
        let client = connect(port: port, token: nil)

        await #expect(throws: (any Error).self) { try await client.receive() }
        await server.stop()
    }

    @Test
    func aClientWithAWrongTokenIsRefused() async throws {
        let (server, port) = try await makeServer()
        let client = connect(port: port, token: "wrong-token")

        await #expect(throws: (any Error).self) { try await client.receive() }
        await server.stop()
    }

    @Test
    func aBrowserOriginIsRefusedEvenWithTheToken() async throws {
        let (server, port) = try await makeServer()
        let control = connect(port: port, token: token)
        let controlHello = try await receiveMessage(from: control)
        #expect(controlHello.type == "hello")
        control.cancel(with: .goingAway, reason: nil)

        let browser = connect(port: port, token: token, origin: "http://evil.example")

        await #expect(throws: (any Error).self) { try await browser.receive() }
        await server.stop()
    }

    @Test
    func anAllowedBrowserOriginIsAccepted() async throws {
        let (server, port) = try await makeServer()
        await server.allow(origin: "http://127.0.0.1:9999")
        let client = connect(port: port, token: token, origin: "http://127.0.0.1:9999")

        let hello = try await receiveMessage(from: client)

        #expect(hello.type == "hello")
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func anIncompatibleProtocolGetsAClearReplyAndTheConnectionIsClosed() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = connect(port: port, token: token)
        _ = try await receiveMessage(from: client)

        try await client.send(.string(#"{"type":"hello","protocolVersion":999}"#))
        let reply = try await receiveMessage(from: client)

        #expect(reply.type == "incompatible")
        #expect(reply.supportedProtocolVersion == PlaygroundChannel.protocolVersion)
        #expect(reply.reason?.contains("999") == true)
        await #expect(throws: (any Error).self) { try await client.receive() }
        #expect(await session.calls.isEmpty)
        await server.stop()
    }

    @Test
    func aTapBeforeTheHelloClosesTheConnectionWithoutTapping() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = connect(port: port, token: token)
        _ = try await receiveMessage(from: client)

        try await client.send(.string(#"{"type":"tap","x":0.5,"y":0.5}"#))

        await #expect(throws: (any Error).self) { try await client.receive() }
        #expect(await session.calls.isEmpty)
        await server.stop()
    }

    @Test
    func aTapAfterTheHelloReachesTheSessionAsANormalizedPoint() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"tap","x":0.5,"y":0.25}"#))

        let expected = MockSimulatorSession.Call.tap(NormalizedPoint(horizontal: 0.5, vertical: 0.25))
        #expect(await waitUntil { await session.calls.contains(expected) })
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func messagesThatAreNotTapsAreIgnored() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)

        try await client.send(.string("not json"))
        try await client.send(.string(#"{"type":"tap","x":3,"y":0.2}"#))
        try await client.send(.string(#"{"type":"tap","x":0.1,"y":0.2}"#))

        let expected = MockSimulatorSession.Call.tap(NormalizedPoint(horizontal: 0.1, vertical: 0.2))
        #expect(await waitUntil { await session.calls.contains(expected) })
        #expect(await session.calls.filter { if case .tap = $0 { true } else { false } }.count == 1)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func theLatestFrameIsSentAsABinaryMessageAfterTheHello() async throws {
        let (server, port) = try await makeServer(session: makeSession(frames: [frame]))
        let client = try await handshake(port: port)

        let message = try await client.receive()

        guard case let .data(data) = message else {
            Issue.record("expected a binary frame, got \(message)")
            return
        }
        #expect(data == frame.jpegData)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aViewerTapIsVerifiedAndTheOutcomeIsReported() async throws {
        let observer = MockSimulatorScreenObserver(digests: ["before", "after"])
        let verifier = SimulatorTapVerifier(observer: observer, settleDuration: .zero)
        let output = OutputRecorder()
        let (server, port) = try await makeServer(verifier: verifier, output: output.record)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"tap","x":0.5,"y":0.25}"#))

        #expect(await waitUntil { output.text.contains("Tap delivered") })
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func theServerKeepsServingAfterAClientDisconnects() async throws {
        let (server, port) = try await makeServer()
        let first = try await handshake(port: port)
        first.cancel(with: .goingAway, reason: nil)

        let second = connect(port: port, token: token)
        let hello = try await receiveMessage(from: second)

        #expect(hello.type == "hello")
        second.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    // MARK: - Helpers

    private func makeSession(frames: [SimulatorFrame] = []) -> MockSimulatorSession {
        MockSimulatorSession(probeResult: supportedProbe, framesToEmit: frames)
    }

    private func makeServer(
        session: MockSimulatorSession? = nil,
        verifier: SimulatorTapVerifier? = nil,
        output: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> (PlaygroundChannelServer, UInt16) {
        let server = PlaygroundChannelServer(
            session: session ?? makeSession(),
            token: token,
            verifier: verifier,
            output: output,
            port: 0
        )
        return (server, try await server.start())
    }

    private func connect(port: UInt16, token: String?, origin: String? = nil) -> URLSessionWebSocketTask {
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
    private func handshake(port: UInt16) async throws -> URLSessionWebSocketTask {
        let client = connect(port: port, token: token)
        _ = try await receiveMessage(from: client)
        let hello = #"{"type":"hello","protocolVersion":\#(PlaygroundChannel.protocolVersion)}"#
        try await client.send(.string(hello))
        return client
    }

    private func receiveMessage(from client: URLSessionWebSocketTask) async throws -> PlaygroundServerMessage {
        guard case let .string(text) = try await client.receive() else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try JSONDecoder().decode(PlaygroundServerMessage.self, from: Data(text.utf8))
    }

    private var supportedProbe: SimulatorProbeResult {
        SimulatorProbeResult(status: .supported, xcodeVersion: "27.1", coreSimulatorVersion: "1155.4", issues: [])
    }
}

private final class OutputRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    var text: String { lock.withLock { lines.joined(separator: "\n") } }
    func record(_ line: String) { lock.withLock { lines.append(line) } }
}

private func waitUntil(timeout: Duration = .seconds(3), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return false
}
