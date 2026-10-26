/// How showing a component is going, sent back to the client that asked.
struct PlaygroundComponentStatus: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable {
        case building
        case ready
        case failed
        case cleared
    }

    let id: String
    let state: State
    let message: String?
    let diagnostics: [PlaygroundDiagnostic]

    init(id: String, state: State, message: String? = nil, diagnostics: [PlaygroundDiagnostic] = []) {
        self.id = id
        self.state = state
        self.message = message
        self.diagnostics = diagnostics
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case state
        case message
        case diagnostics
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        state = try container.decode(State.self, forKey: .state)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        diagnostics = try container.decodeIfPresent([PlaygroundDiagnostic].self, forKey: .diagnostics) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("componentStatus", forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encode(diagnostics, forKey: .diagnostics)
    }
}
