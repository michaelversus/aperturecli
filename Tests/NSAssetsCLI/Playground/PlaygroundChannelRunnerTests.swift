import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundChannelRunnerTests {
    private let token = "secret-token"

    @Test
    func announcesThePortTokenAndVersionsThroughTheNotificationCenter() async throws {
        let poster = MockDistributedNotificationPoster()
        let ready = PortSignal()
        let (runner, _) = makeRunner(poster: poster, onReady: { ready.set($0) })

        let run = Task { try await runner.run() }
        let port = try #require(await waitForValue { ready.port })
        run.cancel()
        _ = try? await run.value

        let post = try #require(poster.posts.first)
        #expect(post.name == PlaygroundChannel.notificationName)
        #expect(post.userInfo["port"] as? Int == Int(port))
        #expect(post.userInfo["token"] as? String == token)
        #expect(post.userInfo["cliVersion"] as? String == version)
        #expect(post.userInfo["protocolVersion"] as? Int == PlaygroundChannel.protocolVersion)
        #expect(post.userInfo["simulatorUDID"] as? String == "UDID-1")
        #expect(post.userInfo["workingDirectory"] as? String == "/repo")
    }

    @Test
    func theAnnouncementIsPostedOnlyOnceTheServerIsListening() async throws {
        let poster = MockDistributedNotificationPoster()
        let ready = PortSignal()
        let (runner, _) = makeRunner(poster: poster, onReady: { ready.set($0) })

        let run = Task { try await runner.run() }
        let port = try #require(await waitForValue { ready.port })
        let client = URLSession.shared.webSocketTask(with: websocketRequest(port: port))
        client.resume()
        let message = try await client.receive()
        run.cancel()
        _ = try? await run.value

        guard case .string = message else {
            Issue.record("expected the server hello, got \(message)")
            return
        }
        #expect(poster.posts.count == 1)
    }

    @Test
    func cancellingStopsTheServerSoNewConnectionsFail() async throws {
        let ready = PortSignal()
        let (runner, _) = makeRunner(poster: MockDistributedNotificationPoster(), onReady: { ready.set($0) })

        let run = Task { try await runner.run() }
        let port = try #require(await waitForValue { ready.port })
        run.cancel()
        _ = try? await run.value

        let client = URLSession.shared.webSocketTask(with: websocketRequest(port: port))
        client.resume()
        await #expect(throws: (any Error).self) { try await client.receive() }
    }

    @Test
    func theDebugViewerPageCarriesTheTokenAndItsOriginIsAllowed() async throws {
        let ready = PortSignal()
        let viewerReady = PortSignal()
        let (runner, _) = makeRunner(
            poster: MockDistributedNotificationPoster(),
            debugViewer: PlaygroundDebugViewer(),
            onReady: { ready.set($0) },
            onDebugViewerReady: { viewerReady.set($0) }
        )

        let run = Task { try await runner.run() }
        let port = try #require(await waitForValue { ready.port })
        let viewerPort = try #require(await waitForValue { viewerReady.port })

        let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(viewerPort)/")!)
        let page = try #require(String(bytes: data, encoding: .utf8))
        #expect(page.contains("<canvas"))
        #expect(page.contains("ws://127.0.0.1:\(port)"))
        #expect(page.contains(PlaygroundChannel.subprotocol(token: token)))

        var request = websocketRequest(port: port)
        request.setValue("http://127.0.0.1:\(viewerPort)", forHTTPHeaderField: "Origin")
        let client = URLSession.shared.webSocketTask(with: request)
        client.resume()
        guard case .string = try await client.receive() else {
            Issue.record("the debug viewer origin should have been accepted")
            return
        }
        run.cancel()
        _ = try? await run.value
    }

    // MARK: - Helpers

    private func makeRunner(
        poster: MockDistributedNotificationPoster,
        debugViewer: PlaygroundDebugViewer? = nil,
        onReady: @escaping @Sendable (UInt16) -> Void = { _ in },
        onDebugViewerReady: @escaping @Sendable (UInt16) -> Void = { _ in }
    ) -> (PlaygroundChannelRunner, MockSimulatorSession) {
        let probe = SimulatorProbeResult(
            status: .supported,
            xcodeVersion: "27.1",
            coreSimulatorVersion: nil,
            issues: []
        )
        let session = MockSimulatorSession(probeResult: probe)
        let server = PlaygroundChannelServer(session: session, token: token, port: 0)
        let runner = PlaygroundChannelRunner(
            server: server,
            token: token,
            simulatorUDID: "UDID-1",
            workingDirectory: "/repo",
            poster: poster,
            debugViewer: debugViewer,
            onReady: onReady,
            onDebugViewerReady: onDebugViewerReady
        )
        return (runner, session)
    }

    private func websocketRequest(port: UInt16) -> URLRequest {
        var request = URLRequest(url: URL(string: "ws://127.0.0.1:\(port)")!)
        request.setValue(PlaygroundChannel.subprotocol(token: token), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        return request
    }
}
