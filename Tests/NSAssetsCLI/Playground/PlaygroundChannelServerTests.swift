import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundChannelServerTests: PlaygroundChannelTesting {
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

        #expect(hello.type == .hello)
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
        #expect(controlHello.type == .hello)
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

        #expect(hello.type == .hello)
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

        #expect(reply.type == .incompatible)
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
    func aDragReachesTheSessionAsOneGestureInOrder() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"touch","phase":"start","x":0.5,"y":0.8}"#))
        try await client.send(.string(#"{"type":"touch","phase":"move","x":0.5,"y":0.5}"#))
        try await client.send(.string(#"{"type":"touch","phase":"end","x":0.5,"y":0.2}"#))

        let expected: [MockSimulatorSession.Call] = [
            .touch(.start, NormalizedPoint(horizontal: 0.5, vertical: 0.8)),
            .touch(.position, NormalizedPoint(horizontal: 0.5, vertical: 0.5)),
            .touch(.end, NormalizedPoint(horizontal: 0.5, vertical: 0.2))
        ]
        #expect(await waitUntil { await session.calls.filter(\.isTouch) == expected })
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aMoveOrEndWithoutAStartIsIgnored() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"touch","phase":"move","x":0.5,"y":0.5}"#))
        try await client.send(.string(#"{"type":"touch","phase":"end","x":0.5,"y":0.5}"#))
        try await client.send(.string(#"{"type":"tap","x":0.1,"y":0.2}"#))

        #expect(await waitUntil { await session.calls.contains(.tap(NormalizedPoint(horizontal: 0.1, vertical: 0.2))) })
        #expect(await session.calls.filter(\.isTouch).isEmpty)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aClientThatDisconnectsMidDragLiftsTheFinger() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)
        try await client.send(.string(#"{"type":"touch","phase":"start","x":0.5,"y":0.8}"#))
        try await client.send(.string(#"{"type":"touch","phase":"move","x":0.5,"y":0.4}"#))
        #expect(await waitUntil { await session.calls.filter(\.isTouch).count == 2 })

        client.cancel(with: .goingAway, reason: nil)

        let lifted = MockSimulatorSession.Call.touch(.end, NormalizedPoint(horizontal: 0.5, vertical: 0.4))
        #expect(await waitUntil { await session.calls.contains(lifted) })
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
    func anAuthorizedClientThatNeverSaysHelloIsDisconnected() async throws {
        let (server, port) = try await makeServer(handshakeTimeout: .milliseconds(200))
        let client = connect(port: port, token: token)
        _ = try await receiveMessage(from: client)

        await #expect(throws: (any Error).self) { try await client.receive() }
        await server.stop()
    }

    @Test
    func aTapThatFailsIsReportedInsteadOfSwallowed() async throws {
        let session = MockSimulatorSession(probeResult: supportedProbe, tapError: PlaygroundError.sessionNotStarted)
        let output = OutputRecorder()
        let (server, port) = try await makeServer(session: session, output: output.record)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"tap","x":0.5,"y":0.5}"#))

        #expect(await waitUntil { output.text.contains("Tap failed") })
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

        #expect(hello.type == .hello)
        second.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }
}
