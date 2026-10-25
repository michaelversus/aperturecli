import Foundation
import Network

/// Serves the live frames to authenticated clients over a WebSocket on the loopback interface only, and turns their
/// tap messages into verified taps on the session.
///
/// A connection is refused during the handshake unless it offers the token as its subprotocol and carries no browser
/// `Origin` (except one explicitly allowed for the debug viewer). After the handshake the client must say hello with a
/// protocol number this CLI speaks before it receives frames or can tap.
final class PlaygroundChannelServer: @unchecked Sendable {
    /// Only touched on the server's serial queue.
    private final class Client: @unchecked Sendable {
        let connection: NWConnection
        var isSending = false
        var isHandshaken = false
        init(connection: NWConnection) { self.connection = connection }
    }

    private let session: any SimulatorSession
    private let token: String
    private let verifier: SimulatorTapVerifier?
    private let componentPresenter: (any PlaygroundComponentPresenting)?
    private let output: @Sendable (String) -> Void
    private let tapRunner: PlaygroundTapRunner
    // Taps and components each run one after another: verifying a tap compares screens before and after it, and
    // components share one harness app and one simulator.
    private let taps = SerialTaskQueue()
    private let components = SerialTaskQueue()
    private let requestedPort: UInt16
    private let handshakeTimeout: Duration
    private let queue = DispatchQueue(label: "nsassets.playground.channel")

    // Confined to `queue`.
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private var allowedOrigins: Set<String> = []
    private var latestFrame: Data?
    private var pump: Task<Void, Never>?

    /// With a `verifier`, every tap is checked and its outcome is sent to `output`.
    init(
        session: any SimulatorSession,
        token: String,
        verifier: SimulatorTapVerifier? = nil,
        componentPresenter: (any PlaygroundComponentPresenting)? = nil,
        output: @escaping @Sendable (String) -> Void = { _ in },
        port: UInt16 = 0,
        handshakeTimeout: Duration = .seconds(5)
    ) {
        self.session = session
        self.token = token
        self.verifier = verifier
        self.componentPresenter = componentPresenter
        self.output = output
        self.tapRunner = PlaygroundTapRunner(session: session, verifier: verifier, output: output)
        self.requestedPort = port
        self.handshakeTimeout = handshakeTimeout
    }

    /// Starts listening on loopback, starts the frame pump, and returns the port actually bound.
    func start() async throws -> UInt16 {
        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.setClientRequestHandler(queue) { [weak self] subprotocols, headers in
            // The framework answers a rejected handshake without closing the socket, so clients would hang. Every
            // handshake is accepted instead, and only an authorized one gets the token subprotocol back; the rest
            // are closed with a close frame as soon as the connection is ready.
            let accepted = self?.acceptedSubprotocol(offered: subprotocols, headers: headers)
            return NWProtocolWebSocket.Response(status: .accept, subprotocol: accepted)
        }
        let listener = try LoopbackListener.make(port: requestedPort, webSocketOptions: webSocketOptions)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        queue.async { [self] in self.listener = listener }
        let port = try await LoopbackListener.start(listener, on: queue)

        let session = session
        pump = Task { [weak self] in
            do {
                for try await frame in session.frames() where !frame.isReplay {
                    self?.broadcast(frame.jpegData)
                }
            } catch {
                self?.output("The frame stream stopped: \(error.localizedDescription)")
            }
        }
        return port
    }

    /// Lets browser connections from this origin through, for the hidden debug viewer only.
    func allow(origin: String) async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                allowedOrigins.insert(origin)
                continuation.resume()
            }
        }
    }

    func stop() async {
        pump?.cancel()
        pump = nil
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                listener?.cancel()
                listener = nil
                clients.values.forEach { $0.connection.cancel() }
                clients = [:]
                continuation.resume()
            }
        }
    }

    // MARK: - Handshake

    /// Runs on `queue`. Returns the subprotocol to accept, or `nil` to refuse the connection.
    private func acceptedSubprotocol(
        offered subprotocols: [String],
        headers: [(name: String, value: String)]
    ) -> String? {
        let origin = headers.first { $0.name.caseInsensitiveCompare("Origin") == .orderedSame }?.value
        if let origin, !allowedOrigins.contains(origin) { return nil }
        let expected = PlaygroundChannel.subprotocol(token: token)
        return subprotocols.first { $0 == expected }
    }

    /// Whether the handshake ended with the token subprotocol, which `acceptedSubprotocol` grants only to
    /// authorized clients.
    private func isAuthorized(_ connection: NWConnection) -> Bool {
        let metadata = connection.metadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
        return metadata?.selectedSubprotocol == PlaygroundChannel.subprotocol(token: token)
    }

    // MARK: - Clients

    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        let key = ObjectIdentifier(client)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard isAuthorized(connection) else {
                    close(client)
                    return
                }
                clients[key] = client
                sendJSON(PlaygroundServerMessage.hello(), to: client)
                receive(from: client)
                closeUnlessHandshaken(client)
            case .failed, .cancelled:
                clients[key] = nil
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    /// An authorized client that never says hello would otherwise stay connected forever.
    private func closeUnlessHandshaken(_ client: Client) {
        let components = handshakeTimeout.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        queue.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if !client.isHandshaken { self?.close(client) }
        }
    }

    private func receive(from client: Client) {
        client.connection.receiveMessage { [weak self] data, context, _, error in
            guard let self else { return }
            let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                as? NWProtocolWebSocket.Metadata
            if let data, metadata?.opcode == .text { handle(text: data, from: client) }
            if error == nil { receive(from: client) }
        }
    }

    private func handle(text: Data, from client: Client) {
        let message = try? JSONDecoder().decode(PlaygroundClientMessage.self, from: text)
        guard client.isHandshaken else {
            completeHandshake(of: client, with: message)
            return
        }
        guard let message else { return }
        if message.type == .showComponent {
            handleComponentRequest(text, from: client)
            return
        }
        guard let point = message.tapPoint else { return }
        let tapRunner = tapRunner
        taps.enqueue { await tapRunner.run(point) }
    }

    /// Components are presented one after another, because they share one harness app and one simulator.
    private func handleComponentRequest(_ text: Data, from client: Client) {
        let request: PlaygroundComponentRequest
        do {
            request = try JSONDecoder().decode(PlaygroundComponentRequest.self, from: text)
        } catch {
            sendJSON(
                PlaygroundComponentStatus(
                    id: requestID(in: text),
                    state: .failed,
                    message: "The component request was malformed: \(error.localizedDescription)"
                ),
                to: client
            )
            return
        }
        guard let componentPresenter else {
            sendJSON(
                PlaygroundComponentStatus(
                    id: request.id,
                    state: .failed,
                    message: "Components are not available in this session."
                ),
                to: client
            )
            return
        }
        components.enqueue { [self] in
            await componentPresenter.present(request) { status in
                queue.async { self.sendJSON(status, to: client) }
            }
        }
    }

    private func requestID(in text: Data) -> String {
        (try? JSONSerialization.jsonObject(with: text) as? [String: Any])?["id"] as? String ?? ""
    }

    private func completeHandshake(of client: Client, with message: PlaygroundClientMessage?) {
        guard message?.type == .hello, message?.protocolVersion == PlaygroundChannel.protocolVersion else {
            if message?.type == .hello {
                sendJSON(
                    PlaygroundServerMessage.incompatible(clientProtocolVersion: message?.protocolVersion),
                    to: client,
                    thenClose: true
                )
            } else {
                close(client)
            }
            return
        }
        client.isHandshaken = true
        if let latestFrame { send(latestFrame, to: client) }
    }

    // MARK: - Sending

    private func broadcast(_ frame: Data) {
        queue.async { [self] in
            latestFrame = frame
            for client in clients.values where client.isHandshaken && !client.isSending { send(frame, to: client) }
        }
    }

    /// A client that is still sending skips frames, so a slow client sees the latest frame, not a backlog.
    private func send(_ frame: Data, to client: Client) {
        client.isSending = true
        let context = NWConnection.ContentContext(
            identifier: "frame",
            metadata: [NWProtocolWebSocket.Metadata(opcode: .binary)]
        )
        client.connection.send(
            content: frame,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { [weak self] _ in
                self?.queue.async { client.isSending = false }
            }
        )
    }

    private func sendJSON(_ message: some Encodable, to client: Client, thenClose: Bool = false) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        let context = NWConnection.ContentContext(
            identifier: "text",
            metadata: [NWProtocolWebSocket.Metadata(opcode: .text)]
        )
        client.connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { [weak self] _ in
                guard thenClose, let self else { return }
                queue.async { self.close(client) }
            }
        )
    }

    private func close(_ client: Client) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = .protocolCode(.policyViolation)
        let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
        client.connection.send(
            content: nil,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { _ in client.connection.cancel() }
        )
    }
}
