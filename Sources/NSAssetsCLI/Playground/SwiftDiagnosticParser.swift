import Foundation

/// Turns `swiftc` output into diagnostics located in the code the app sent.
struct SwiftDiagnosticParser {
    private static let located = try? NSRegularExpression(pattern: #"^(.*?):(\d+):(\d+): (error|warning|note): (.*)$"#)
    private static let unlocated = try? NSRegularExpression(pattern: #"^(error|warning): (.*)$"#)

    /// Where the app's entry expression sits in the generated entry file.
    let entryFirstLine: Int
    let entryLineCount: Int

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
            // Only the expression is the app's; the generated wrapper around it is the harness.
            let inExpression = (entryFirstLine..<(entryFirstLine + entryLineCount)).contains(lineNumber)
            file = inExpression ? .entry : .harness
            adjustedLine = inExpression ? lineNumber - entryFirstLine + 1 : lineNumber
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
