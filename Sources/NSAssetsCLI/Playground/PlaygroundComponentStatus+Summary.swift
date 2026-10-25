extension PlaygroundComponentStatus {
    /// One line for the terminal: the state, the message, and each diagnostic with its location.
    var summary: String {
        var parts = [state.rawValue]
        if let message { parts.append(message) }
        for diagnostic in diagnostics {
            parts.append("[\(diagnostic.location)] \(diagnostic.message)")
        }
        return parts.joined(separator: " ")
    }
}
