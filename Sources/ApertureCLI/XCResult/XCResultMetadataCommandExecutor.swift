import Foundation

struct XCResultMetadataCommandExecutor {
    let fileSystem: FileSystemProvider
    let now: () -> Date
    let output: (String) -> Void

    init(
        fileSystem: FileSystemProvider,
        now: @escaping () -> Date = Date.init,
        output: @escaping (String) -> Void
    ) {
        self.fileSystem = fileSystem
        self.now = now
        self.output = output
    }

    func run(schemeName: String, projectName: String, workspacePath: String? = nil) throws {
        let timestampDate = now()
        let repoRoot = resolveRepoRoot(workspacePath: workspacePath)
        let artifactsDirectory = URL(fileURLWithPath: repoRoot, isDirectory: true)
            .appendingPathComponent("aperture-artifacts", isDirectory: true)
            .appendingPathComponent("xcresult-metadata", isDirectory: true)
        try fileSystem.createDirectory(
            atPath: artifactsDirectory.path,
            withIntermediateDirectories: true
        )

        let timestamp = metadataTimestampFormatter.string(from: timestampDate)
        let artifactPath = artifactsDirectory
            .appendingPathComponent("\(timestamp)-\(sanitizePathComponent(schemeName)).json", isDirectory: false)
            .path

        let payload = XCResultParseMetadata(
            triggeredAt: ISO8601DateFormatter().string(from: timestampDate),
            schemeName: schemeName,
            projectName: projectName,
            workspacePath: workspacePath?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try fileSystem.writeFile(json + "\n", toPath: artifactPath)
        output(artifactPath)
    }

    private func resolveRepoRoot(workspacePath: String?) -> String {
        if let workspacePath {
            let trimmed = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return repoRoot(fromWorkspacePath: trimmed)
            }
        }

        return resolveRepoRoot(startingAt: fileSystem.currentDirectoryPath())
    }

    private func repoRoot(fromWorkspacePath workspacePath: String) -> String {
        let workspaceURL = URL(fileURLWithPath: workspacePath).standardizedFileURL
        let workspaceDirectoryURL = workspaceURL.deletingLastPathComponent()

        if workspaceDirectoryURL.pathExtension == "xcodeproj" {
            return workspaceDirectoryURL.deletingLastPathComponent().path
        }

        return workspaceDirectoryURL.path
    }

    private func resolveRepoRoot(startingAt path: String) -> String {
        var current = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        while true {
            let gitPath = URL(fileURLWithPath: current, isDirectory: true)
                .appendingPathComponent(".git", isDirectory: true)
                .path
            if fileSystem.fileExists(atPath: gitPath) {
                return current
            }

            let parent = URL(fileURLWithPath: current, isDirectory: true)
                .deletingLastPathComponent()
                .path
            if parent == current || parent.isEmpty {
                return path
            }
            current = parent
        }
    }

    private func sanitizePathComponent(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "_",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    private var metadataTimestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }
}
