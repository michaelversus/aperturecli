import Foundation
import Testing
@testable import NSAssetsCLI

struct CLIMarkerWriterTests {
    private let instant = Date(timeIntervalSince1970: 1_792_929_600)

    @Test
    func writesTheCurrentVersionsIntoTheArtifactsFolder() throws {
        let fileSystem = MockFileSystem()
        let writer = CLIMarkerWriter(fileSystem: fileSystem, now: { instant })

        writer.write(atRootPath: "/repo")

        #expect(fileSystem.createDirectoryOperations.map(\.path) == ["/repo/nsassets-artifacts"])
        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.path == "/repo/nsassets-artifacts/cli.json")
        let marker = try JSONDecoder().decode(CLIMarker.self, from: Data(write.contents.utf8))
        #expect(marker == CLIMarker(
            cliVersion: version,
            protocolVersion: PlaygroundChannel.protocolVersion,
            updatedAt: instant.formatted(.iso8601)
        ))
    }

    @Test
    func ignoresAFailureToWrite() {
        let writer = CLIMarkerWriter(fileSystem: FailingFileSystem(), now: { instant })

        writer.write(atRootPath: "/repo")
    }
}

private final class FailingFileSystem: FileSystemProvider {
    func fileExists(atPath path: String) -> Bool { false }
    func currentDirectoryPath() -> String { "/repo" }
    func libraryDirectory() -> URL { URL(fileURLWithPath: "/tmp") }
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] { [] }
    func recursiveContentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] { [] }
    func readFile(atPath path: String) throws -> String { "" }
    func readLines(atPath path: String) throws -> [String] { [] }
    func writeFile(_ contents: String, toPath path: String) throws { throw CocoaError(.fileWriteNoPermission) }
    func removeItem(atPath path: String) throws {}
    func createDirectory(atPath path: String, withIntermediateDirectories: Bool) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}
