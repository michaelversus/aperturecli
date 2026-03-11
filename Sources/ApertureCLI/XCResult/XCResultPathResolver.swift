import Foundation

struct XCResultPathResolver: XCResultPathResolving {
    let fileSystem: FileSystemProvider
    let derivedDataLocator: DerivedDataLocatorProtocol

    func resolvePath(schemeName: String, projectName: String) throws -> String {
        let trimmedSchemeName = schemeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProjectName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSchemeName.isEmpty, !trimmedProjectName.isEmpty else {
            throw XCResultPathResolverError.invalidArguments
        }

        let derivedDataPaths = try derivedDataLocator.locateDerivedData(projectName: trimmedProjectName)
        let testLogsDirectory = derivedDataPaths.derivedDataURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Test", isDirectory: true)

        guard fileSystem.fileExists(atPath: testLogsDirectory.path) else {
            throw XCResultPathResolverError.missingTestLogsDirectory(path: testLogsDirectory.path)
        }

        let files = try fileSystem.contentsOfDirectory(
            at: testLogsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let xcresultFiles = files.filter { $0.pathExtension.caseInsensitiveCompare("xcresult") == .orderedSame }
        guard !xcresultFiles.isEmpty else {
            throw XCResultPathResolverError.noXCResultFiles(path: testLogsDirectory.path)
        }

        let normalizedSchemeToken = normalizedToken(from: trimmedSchemeName)
        // Matching is filename-based (not bundle-content based).
        // We normalize separators to "-" and compare token boundaries.
        // Examples for scheme "Snapshot Tests":
        // - "Run-Snapshot-Tests.xcresult"        -> match (exact token)
        // - "MyApp.snapshot_tests.123.xcresult"  -> match (contains token with separators)
        // - "OtherScheme-Run.xcresult"           -> no match
        let matching = xcresultFiles.filter { url in
            matchesScheme(fileName: url.deletingPathExtension().lastPathComponent, schemeToken: normalizedSchemeToken)
        }
        guard !matching.isEmpty else {
            throw XCResultPathResolverError.noSchemeMatch(
                schemeName: trimmedSchemeName,
                searchPath: testLogsDirectory.path
            )
        }

        let newest = matching.max { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast

            if lhsDate == rhsDate {
                return lhs.path < rhs.path
            }
            return lhsDate < rhsDate
        }

        return newest?.path ?? matching[0].path
    }

    private func normalizedToken(from value: String) -> String {
        // "Snapshot Tests" -> "snapshot-tests"
        // "snapshot_tests" -> "snapshot-tests"
        // "snapshot.tests" -> "snapshot-tests"
        let lower = value.lowercased()
        let pieces = lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return pieces.joined(separator: "-")
    }

    private func matchesScheme(fileName: String, schemeToken: String) -> Bool {
        // Boundary-aware token checks avoid partial collisions, e.g.
        // scheme "snap" should not match filename token "snapshot".
        let fileToken = normalizedToken(from: fileName)
        if fileToken == schemeToken {
            return true
        }
        return fileToken.hasPrefix(schemeToken + "-")
            || fileToken.hasSuffix("-" + schemeToken)
            || fileToken.contains("-" + schemeToken + "-")
    }
}
