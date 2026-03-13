import Foundation

struct XCResultParseCommandExecutor {
    struct ArtifactDirectories {
        let artifactPath: String
        let schemeAttachmentsDirectory: URL
    }

    let fileSystem: FileSystemProvider
    let resolver: XCResultPathResolving
    let xcresultToolClient: XCResultToolProviding
    let appBridge: AppBridgeHandling
    let output: (String) -> Void

    init(
        fileSystem: FileSystemProvider,
        resolver: XCResultPathResolving,
        xcresultToolClient: XCResultToolProviding,
        appBridge: AppBridgeHandling = NoopAppBridge(),
        output: @escaping (String) -> Void
    ) {
        self.fileSystem = fileSystem
        self.resolver = resolver
        self.xcresultToolClient = xcresultToolClient
        self.appBridge = appBridge
        self.output = output
    }

    func run(schemeName: String, projectName: String, workspacePath: String? = nil) throws {
        let xcresultPath = try resolver.resolvePath(schemeName: schemeName, projectName: projectName)
        let summary = try xcresultToolClient.fetchSummary(xcresultPath: xcresultPath)
        let directories = try prepareArtifactDirectories(
            schemeName: schemeName,
            workspacePath: workspacePath
        )

        let parseResult = try parseFailedTests(
            testFailures: summary.testFailures,
            xcresultPath: xcresultPath,
            schemeAttachmentsDirectory: directories.schemeAttachmentsDirectory
        )

        let payload = XCResultParseArtifact(
            schemeName: schemeName,
            projectName: projectName,
            xcresultPath: xcresultPath,
            title: summary.title,
            environmentDescription: summary.environmentDescription,
            result: summary.result,
            startTime: summary.startTime,
            finishTime: summary.finishTime,
            totalTestCount: summary.totalTestCount,
            passedTests: summary.passedTests,
            failedTests: summary.failedTests,
            skippedTests: summary.skippedTests,
            expectedFailures: summary.expectedFailures,
            devicesAndConfigurations: summary.devicesAndConfigurations,
            failedTestDetails: parseResult.failedTests,
            warnings: parseResult.warnings
        )

        let data = try JSONEncoder.prettySorted.encode(payload)
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        try fileSystem.writeFile(json + "\n", toPath: directories.artifactPath)
        output(directories.artifactPath)

        appBridge.notifyAppIfNeeded(
            payload: AppNotificationPayload(
                schemeName: schemeName,
                projectName: projectName,
                artifactPath: directories.artifactPath,
                xcresultPath: xcresultPath
            )
        )
    }

    func resolveRepoRoot(workspacePath: String?) -> String {
        if let workspacePath {
            let trimmed = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return repoRoot(fromWorkspacePath: trimmed)
            }
        }

        return resolveRepoRoot(startingAt: fileSystem.currentDirectoryPath())
    }

    func repoRoot(fromWorkspacePath workspacePath: String) -> String {
        let workspaceURL = URL(fileURLWithPath: workspacePath).standardizedFileURL
        let workspaceDirectoryURL = workspaceURL.deletingLastPathComponent()

        if workspaceDirectoryURL.pathExtension == "xcodeproj" {
            return workspaceDirectoryURL.deletingLastPathComponent().path
        }

        return workspaceDirectoryURL.path
    }

    func resolveRepoRoot(startingAt path: String) -> String {
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
