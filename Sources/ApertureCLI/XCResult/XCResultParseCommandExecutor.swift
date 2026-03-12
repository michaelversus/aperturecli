import Foundation

struct XCResultParseCommandExecutor {
    let fileSystem: FileSystemProvider
    let resolver: XCResultPathResolving
    let output: (String) -> Void

    func run(schemeName: String, projectName: String, workspacePath: String? = nil) throws {
        let path = try resolver.resolvePath(
            schemeName: schemeName,
            projectName: projectName
        )
        let resolvedRepoRoot = resolveRepoRoot(workspacePath: workspacePath)
        let artifactsDirectory = URL(fileURLWithPath: resolvedRepoRoot, isDirectory: true)
            .appendingPathComponent("aperture-artifacts", isDirectory: true)
            .appendingPathComponent("xcresults", isDirectory: true)
        try fileSystem.createDirectory(
            atPath: artifactsDirectory.path,
            withIntermediateDirectories: true
        )

        let artifactPath = artifactsDirectory
            .appendingPathComponent("\(schemeName).json", isDirectory: false)
            .path
        let payload = [schemeName: path]
        let data = try JSONEncoder.prettySorted.encode(payload)
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
}

private extension JSONEncoder {
    static var prettySorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
