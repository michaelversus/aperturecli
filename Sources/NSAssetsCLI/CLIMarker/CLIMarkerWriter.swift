import Foundation

/// Writes `nsassets-artifacts/cli.json`. The file lives in the gitignored artifacts folder because its version changes
/// on every upgrade; a failure to write it is ignored.
struct CLIMarkerWriter: CLIMarkerWriting {
    let fileSystem: FileSystemProvider
    var now: () -> Date = Date.init

    func write(atRootPath rootPath: String) {
        let directory = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent("nsassets-artifacts", isDirectory: true)
        let marker = CLIMarker(
            cliVersion: version,
            protocolVersion: PlaygroundChannel.protocolVersion,
            updatedAt: now().formatted(.iso8601)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try fileSystem.createDirectory(atPath: directory.path, withIntermediateDirectories: true)
            let data = try encoder.encode(marker)
            try fileSystem.writeFile(
                String(decoding: data, as: UTF8.self),
                toPath: directory.appendingPathComponent("cli.json").path
            )
        } catch {
            // The marker is a convenience for the app; it must never fail a command.
        }
    }
}
