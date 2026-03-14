import Foundation

struct XCResultToolClient: XCResultToolProviding {
    let commandRunner: CommandRunning
    let fileSystem: FileSystemProvider

    func fetchSummary(xcresultPath: String) throws -> XCResultToolModels.Summary {
        let arguments = [
            "xcresulttool", "get", "test-results", "summary",
            "--path", xcresultPath
        ]
        emitSummaryDiagnostics(xcresultPath: xcresultPath)
        Thread.sleep(forTimeInterval: 2.0)
        let output = try runCommandWithRetry(
            executable: "/usr/bin/xcrun",
            arguments: arguments
        )
        return try decode(
            XCResultToolModels.Summary.self,
            from: output,
            command: "/usr/bin/xcrun \(arguments.joined(separator: " "))"
        )
    }

    func fetchTestDetails(
        xcresultPath: String,
        testIdentifier: String
    ) throws -> XCResultToolModels.TestDetails {
        let arguments = [
            "xcresulttool", "get", "test-results", "test-details",
            "--path", xcresultPath,
            "--test-id", testIdentifier
        ]
        let output = try commandRunner.run(executable: "/usr/bin/xcrun", arguments: arguments)
        return try decode(
            XCResultToolModels.TestDetails.self,
            from: output,
            command: "/usr/bin/xcrun \(arguments.joined(separator: " "))"
        )
    }

    func fetchTestActivities(
        xcresultPath: String,
        testIdentifier: String
    ) throws -> XCResultToolModels.TestActivities {
        let arguments = [
            "xcresulttool", "get", "test-results", "activities",
            "--path", xcresultPath,
            "--test-id", testIdentifier
        ]
        let output = try commandRunner.run(executable: "/usr/bin/xcrun", arguments: arguments)
        return try decode(
            XCResultToolModels.TestActivities.self,
            from: output,
            command: "/usr/bin/xcrun \(arguments.joined(separator: " "))"
        )
    }

    func exportAttachments(
        xcresultPath: String,
        testIdentifier: String,
        outputPath: String
    ) throws -> [XCResultToolModels.ExportedAttachmentManifestEntry] {
        let arguments = [
            "xcresulttool", "export", "attachments",
            "--path", xcresultPath,
            "--test-id", testIdentifier,
            "--output-path", outputPath
        ]
        _ = try commandRunner.run(executable: "/usr/bin/xcrun", arguments: arguments)

        let manifestPath = URL(fileURLWithPath: outputPath, isDirectory: true)
            .appendingPathComponent("manifest.json", isDirectory: false)
            .path
        guard fileSystem.fileExists(atPath: manifestPath) else {
            throw XCResultToolClientError.missingManifest(path: manifestPath)
        }

        let manifest = try fileSystem.readFile(atPath: manifestPath)
        return try decode(
            [XCResultToolModels.ExportedAttachmentManifestEntry].self,
            from: manifest,
            command: "/usr/bin/xcrun \(arguments.joined(separator: " "))"
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from source: String, command: String) throws -> T {
        let data = Data(source.utf8)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw XCResultToolClientError.invalidJSON(
                command: command,
                underlying: error.localizedDescription
            )
        }
    }

    private func runCommandWithRetry(executable: String, arguments: [String]) throws -> String {
        // Keep retrying transient "bundle not ready" errors for up to 60 seconds.
        let retryWindowSeconds = 60.0
        let maxDelaySeconds = 5.0
        let startDate = Date()
        var delaySeconds = 0.25
        var attempt = 0

        while true {
            attempt += 1
            do {
                emitDiagnostic("xcresult summary attempt=\(attempt)")
                return try commandRunner.run(executable: executable, arguments: arguments)
            } catch {
                let elapsed = Date().timeIntervalSince(startDate)
                guard elapsed < retryWindowSeconds, isTransientXCResultReadinessError(error) else {
                    emitDiagnostic(
                        "xcresult summary failed after \(attempt) attempts elapsed="
                            + String(format: "%.2f", elapsed)
                            + "s error=\(error.localizedDescription)"
                    )
                    throw error
                }
                emitDiagnostic(
                    "xcresult summary transient failure attempt=\(attempt) elapsed="
                        + String(format: "%.2f", elapsed)
                        + "s retry_in="
                        + String(format: "%.2f", delaySeconds)
                        + "s error=\(error.localizedDescription)"
                )
                Thread.sleep(forTimeInterval: delaySeconds)
                delaySeconds = min(delaySeconds * 2, maxDelaySeconds)
            }
        }
    }

    private func isTransientXCResultReadinessError(_ error: Error) -> Bool {
        guard case let SubprocessRunnerError.commandFailed(_, _, _, output) = error else {
            return false
        }
        let normalizedOutput = output.lowercased()
        return normalizedOutput.contains("info.plist")
            && normalizedOutput.contains("does not exist")
            && normalizedOutput.contains("result bundle")
    }

    private func emitSummaryDiagnostics(xcresultPath: String) {
        let infoPlistPath = URL(fileURLWithPath: xcresultPath, isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)
            .path
        let databasePath = URL(fileURLWithPath: xcresultPath, isDirectory: true)
            .appendingPathComponent("database.sqlite3", isDirectory: false)
            .path
        let cwd = FileManager.default.currentDirectoryPath

        emitDiagnostic(
            "xcresult summary preflight path=\(xcresultPath)"
                + " cwd=\(cwd)"
                + " uid=\(getuid())"
                + " gid=\(getgid())"
        )
        emitDiagnostic(
            "xcresult summary preflight exists bundle=\(fileSystem.fileExists(atPath: xcresultPath))"
                + " info=\(fileSystem.fileExists(atPath: infoPlistPath))"
                + " database=\(fileSystem.fileExists(atPath: databasePath))"
        )
    }

    private func emitDiagnostic(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        Swift.print("[nsassets][XCResult] \(timestamp) \(message)")
    }
}
