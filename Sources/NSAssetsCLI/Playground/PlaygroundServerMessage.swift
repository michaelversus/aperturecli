/// A text message from the CLI to a connected client.
struct PlaygroundServerMessage: Codable, Equatable {
    let type: String
    let cliVersion: String?
    let protocolVersion: Int?
    let supportedProtocolVersion: Int?
    let reason: String?

    static func hello() -> PlaygroundServerMessage {
        PlaygroundServerMessage(
            type: "hello",
            cliVersion: version,
            protocolVersion: PlaygroundChannel.protocolVersion,
            supportedProtocolVersion: nil,
            reason: nil
        )
    }

    static func incompatible(clientProtocolVersion: Int?) -> PlaygroundServerMessage {
        let client = clientProtocolVersion.map(String.init) ?? "none"
        return PlaygroundServerMessage(
            type: "incompatible",
            cliVersion: version,
            protocolVersion: nil,
            supportedProtocolVersion: PlaygroundChannel.protocolVersion,
            reason: "Client protocol \(client) is not supported; this CLI speaks protocol "
                + "\(PlaygroundChannel.protocolVersion). Update the CLI or the app."
        )
    }
}
