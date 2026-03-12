import Foundation

struct XCResultToolClient: XCResultToolProviding {
    let commandRunner: CommandRunning
    let fileSystem: FileSystemProvider

    func fetchSummary(xcresultPath: String) throws -> XCResultToolModels.Summary {
        let arguments = [
            "xcresulttool", "get", "test-results", "summary",
            "--path", xcresultPath
        ]
        let output = try commandRunner.run(executable: "/usr/bin/xcrun", arguments: arguments)
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
}

