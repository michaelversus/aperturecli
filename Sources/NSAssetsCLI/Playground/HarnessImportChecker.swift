import Foundation

/// Finds imports of modules the harness cannot see, so they fail with a clear message instead of a compiler error.
struct HarnessImportChecker {
    private static let importPattern = try? NSRegularExpression(
        pattern: #"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|internal|package|private|fileprivate)\s+)?"#
            + #"import\s+(?:(?:struct|class|enum|protocol|typealias|func|var|let)\s+)?([A-Za-z_][A-Za-z0-9_]*)"#
    )

    let isSystemModule: (String) -> Bool

    func diagnostics(forSource source: String) -> [PlaygroundDiagnostic] {
        guard let pattern = Self.importPattern else { return [] }
        var diagnostics: [PlaygroundDiagnostic] = []
        for (index, line) in source.components(separatedBy: "\n").enumerated() {
            // Several statements can share a line, so each one after a semicolon is checked on its own.
            for statement in line.components(separatedBy: ";") {
                let range = NSRange(statement.startIndex..., in: statement)
                guard let match = pattern.firstMatch(in: statement, range: range),
                      let moduleRange = Range(match.range(at: 1), in: statement)
                else { continue }
                let module = String(statement[moduleRange])
                guard !isSystemModule(module) else { continue }
                diagnostics.append(
                    PlaygroundDiagnostic(
                        file: .component,
                        line: index + 1,
                        column: nil,
                        severity: .error,
                        message: "Module '\(module)' is not part of the iOS SDK. The playground builds this "
                            + "component on its own, so inline the code it needs instead of importing it."
                    )
                )
            }
        }
        return diagnostics
    }
}
