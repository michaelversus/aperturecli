/// A compiler or pre-build problem, located in the code the app sent.
struct PlaygroundDiagnostic: Codable, Equatable, Sendable {
    enum File: String, Codable, Sendable {
        /// The component source exactly as the app sent it; lines match.
        case component
        /// The entry expression; lines count from its first line.
        case entry
        /// The generated harness, which points at a CLI bug or an unsupported setup.
        case harness
    }

    enum Severity: String, Codable, Sendable {
        case error
        case warning
    }

    let file: File
    let line: Int?
    let column: Int?
    let severity: Severity
    let message: String
}
