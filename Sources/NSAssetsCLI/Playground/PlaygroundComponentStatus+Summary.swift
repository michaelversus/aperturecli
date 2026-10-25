extension PlaygroundComponentStatus {
    /// One line for the terminal: the state, the message, and each diagnostic with its location.
    var summary: String {
        var parts = [state.rawValue]
        if let message { parts.append(message) }
        for diagnostic in diagnostics {
            let location = diagnostic.line.map { "\(diagnostic.file.rawValue):\($0)" } ?? diagnostic.file.rawValue
            parts.append("[\(location)] \(diagnostic.message)")
        }
        return parts.joined(separator: " ")
    }
}
