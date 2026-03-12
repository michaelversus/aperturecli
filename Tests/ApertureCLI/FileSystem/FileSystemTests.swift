import Foundation
import Testing
@testable import ApertureCLI

struct FileSystemTests {
    @Test
    func writeAndReadFileContents() throws {
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directoryURL) }

        let fileSystem = FileSystem(fileManager: fileManager)
        let fileURL = directoryURL.appendingPathComponent("config.txt")

        try fileSystem.writeFile("first\nsecond\n", toPath: fileURL.path)

        #expect(fileSystem.fileExists(atPath: fileURL.path))
        #expect(try fileSystem.readFile(atPath: fileURL.path) == "first\nsecond\n")
        #expect(try fileSystem.readLines(atPath: fileURL.path) == ["first", "second", ""])
    }

    @Test
    func removesExistingFileSystemItem() throws {
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directoryURL) }

        let nestedDirectoryURL = directoryURL.appendingPathComponent("Nested", isDirectory: true)
        try fileManager.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)

        let fileSystem = FileSystem(fileManager: fileManager)
        #expect(fileSystem.fileExists(atPath: nestedDirectoryURL.path))

        try fileSystem.removeItem(atPath: nestedDirectoryURL.path)

        #expect(!fileSystem.fileExists(atPath: nestedDirectoryURL.path))
    }

    @Test
    func recursivelyEnumeratesDirectoryContents() throws {
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directoryURL) }

        let nestedDirectoryURL = directoryURL.appendingPathComponent("Nested", isDirectory: true)
        try fileManager.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)
        let nestedFileURL = nestedDirectoryURL.appendingPathComponent("file.txt")
        try "content".write(to: nestedFileURL, atomically: true, encoding: .utf8)

        let fileSystem = FileSystem(fileManager: fileManager)
        let items = try fileSystem.recursiveContentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        #expect(items.map(\.standardizedFileURL).contains(nestedFileURL.standardizedFileURL))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
