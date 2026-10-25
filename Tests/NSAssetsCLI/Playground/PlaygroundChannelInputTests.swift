import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundChannelInputTests: PlaygroundChannelTesting {
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
    func keysReachTheSessionInOrderAndARepeatedDownIsIgnored() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)

        for phase in ["down", "down", "up"] {
            try await client.send(.string(#"{"type":"key","code":"KeyA","phase":"\#(phase)"}"#))
        }

        let expected: [MockSimulatorSession.Call] = [.key(usage: 0x04, isDown: true), .key(usage: 0x04, isDown: false)]
        #expect(await waitUntil { await session.calls.filter(\.isKey) == expected })
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func anUpWithoutADownIsIgnored() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"key","code":"KeyA","phase":"up"}"#))
        try await client.send(.string(#"{"type":"tap","x":0.1,"y":0.2}"#))

        #expect(await waitUntil { await session.calls.contains(.tap(NormalizedPoint(horizontal: 0.1, vertical: 0.2))) })
        #expect(await session.calls.filter(\.isKey).isEmpty)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aClientThatDisconnectsWithKeysHeldReleasesThem() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)
        for code in ["ShiftLeft", "KeyA"] {
            try await client.send(.string(#"{"type":"key","code":"\#(code)","phase":"down"}"#))
        }
        #expect(await waitUntil { await session.calls.filter(\.isKey).count == 2 })

        client.cancel(with: .goingAway, reason: nil)

        #expect(await waitUntil {
            let calls = await session.calls
            return calls.contains(.key(usage: 0xE1, isDown: false)) && calls.contains(.key(usage: 0x04, isDown: false))
        })
        await server.stop()
    }

    @Test
    func aButtonPressReachesTheSession() async throws {
        let session = makeSession()
        let (server, port) = try await makeServer(session: session)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"button","button":"lock"}"#))

        #expect(await waitUntil { await session.calls.contains(.press(.lock)) })
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aButtonThatFailsIsReportedInsteadOfSwallowed() async throws {
        let session = MockSimulatorSession(probeResult: supportedProbe, tapError: PlaygroundError.sessionNotStarted)
        let output = OutputRecorder()
        let (server, port) = try await makeServer(session: session, output: { output.record($0) })
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"button","button":"home"}"#))

        #expect(await waitUntil { output.text.contains("Button failed") })
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }
}
