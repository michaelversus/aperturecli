import Foundation

/// Turns `swiftc` output into diagnostics located in the code the app sent.
struct SwiftDiagnosticParser {
    private static let located = try? NSRegularExpression(pattern: #"^(.*?):(\d+):(\d+): (error|warning|note): (.*)$"#)
    private static let unlocated = try? NSRegularExpression(pattern: #"^(error|warning): (.*)$"#)

    /// The line in the generated entry file where the app's entry expression starts.
    let entryFirstLine: Int

    func parse(_ output: String) -> [PlaygroundDiagnostic] {
        output.components(separatedBy: "\n").compactMap(parse(line:))
    }

    private func parse(line: String) -> PlaygroundDiagnostic? {
        let range = NSRange(line.startIndex..., in: line)
        if let match = Self.located?.firstMatch(in: line, range: range) {
            return locatedDiagnostic(from: match, in: line)
        }
        if let match = Self.unlocated?.firstMatch(in: line, range: range),
           let severity = severity(text(match, 1, in: line)) {
            return PlaygroundDiagnostic(
                file: .harness, line: nil, column: nil, severity: severity, message: text(match, 2, in: line)
            )
        }
        return nil
    }

    private func locatedDiagnostic(from match: NSTextCheckingResult, in line: String) -> PlaygroundDiagnostic? {
        guard let severity = severity(text(match, 4, in: line)),
              let lineNumber = Int(text(match, 2, in: line))
        else { return nil }
        let name = URL(fileURLWithPath: text(match, 1, in: line)).lastPathComponent
        let file: PlaygroundDiagnostic.File
        var adjustedLine = lineNumber
        switch name {
        case HarnessSourceGenerator.componentFileName:
            file = .component
        case HarnessSourceGenerator.entryFileName:
            file = .entry
            adjustedLine = max(1, lineNumber - entryFirstLine + 1)
        default:
            file = .harness
        }
        return PlaygroundDiagnostic(
            file: file,
            line: adjustedLine,
            column: Int(text(match, 3, in: line)),
            severity: severity,
            message: text(match, 5, in: line)
        )
    }

    /// Notes explain an earlier diagnostic and are dropped.
    private func severity(_ word: String) -> PlaygroundDiagnostic.Severity? {
        switch word {
        case "error": .error
        case "warning": .warning
        default: nil
        }
    }

    private func text(_ match: NSTextCheckingResult, _ group: Int, in line: String) -> String {
        Range(match.range(at: group), in: line).map { String(line[$0]) } ?? ""
    }
}
