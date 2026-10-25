import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundChannelComponentTests: PlaygroundChannelTesting {
    @Test
    func aComponentRequestIsPresentedAndItsStatusesComeBackToTheRequestingClient() async throws {
        let presenter = MockComponentPresenter()
        let (server, port) = try await makeServer(componentPresenter: presenter)
        let client = try await handshake(port: port)

        try await client.send(.string(componentRequestJSON(id: "req-1")))

        let first = try await receiveStatus(from: client)
        let second = try await receiveStatus(from: client)
        #expect([first.state, second.state] == [.building, .ready])
        #expect(first.id == "req-1")
        #expect(presenter.requests.first?.entry == "A()")
        #expect(presenter.requests.first?.theme == .dark)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aMalformedComponentRequestIsAnsweredWithAFailureNotSilence() async throws {
        let presenter = MockComponentPresenter()
        let (server, port) = try await makeServer(componentPresenter: presenter)
        let client = try await handshake(port: port)

        try await client.send(.string(#"{"type":"showComponent","id":"req-1"}"#))

        let status = try await receiveStatus(from: client)
        #expect(status.state == .failed)
        #expect(status.message?.contains("malformed") == true)
        #expect(presenter.requests.isEmpty)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func withoutAPresenterAComponentRequestIsAnsweredWithAFailure() async throws {
        let (server, port) = try await makeServer()
        let client = try await handshake(port: port)

        try await client.send(.string(componentRequestJSON(id: "req-1")))

        let status = try await receiveStatus(from: client)
        #expect(status.state == .failed)
        #expect(status.id == "req-1")
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }

    @Test
    func aComponentRequestBeforeTheHelloClosesTheConnection() async throws {
        let presenter = MockComponentPresenter()
        let (server, port) = try await makeServer(componentPresenter: presenter)
        let client = connect(port: port, token: token)
        _ = try await receiveMessage(from: client)

        try await client.send(.string(componentRequestJSON(id: "req-1")))

        await #expect(throws: (any Error).self) { try await client.receive() }
        #expect(presenter.requests.isEmpty)
        await server.stop()
    }

    @Test
    func componentsArePresentedOneAtATime() async throws {
        let presenter = MockComponentPresenter(statuses: [.ready], duration: .milliseconds(150))
        let (server, port) = try await makeServer(componentPresenter: presenter)
        let client = try await handshake(port: port)

        try await client.send(.string(componentRequestJSON(id: "a")))
        try await client.send(.string(componentRequestJSON(id: "b")))

        #expect(await waitUntil { presenter.requests.count == 2 })
        try await Task.sleep(for: .milliseconds(400))
        #expect(!presenter.didOverlap)
        client.cancel(with: .goingAway, reason: nil)
        await server.stop()
    }
}
