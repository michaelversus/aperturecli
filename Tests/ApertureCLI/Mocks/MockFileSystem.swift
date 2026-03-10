import Foundation
@testable import ApertureCLI

final class MockFileSystem: FileSystemProvider {
    struct WriteOperation {
        let contents: String
        let path: String
    }

    let currentDirectoryPathValue: String
    let existingPaths: Set<String>
    let directoryContentsByPath: [String: [URL]]
    let recursiveDirectoryContentsByPath: [String: [URL]]
    let fileContentsByPath: [String: String]
    let libraryDirectoryURL: URL

    private(set) var fileExistsCalls: [String] = []
    private(set) var writeOperations: [WriteOperation] = []

    init(
        currentDirectoryPath: String = "/repo",
        existingPaths: Set<String> = [],
        directoryContentsByPath: [String: [URL]] = [:],
        recursiveDirectoryContentsByPath: [String: [URL]] = [:],
        fileContentsByPath: [String: String] = [:],
        libraryDirectoryURL: URL = URL(fileURLWithPath: "/tmp", isDirectory: true)
    ) {
        self.currentDirectoryPathValue = currentDirectoryPath
        self.existingPaths = existingPaths
        self.directoryContentsByPath = directoryContentsByPath
        self.recursiveDirectoryContentsByPath = recursiveDirectoryContentsByPath
        self.fileContentsByPath = fileContentsByPath
        self.libraryDirectoryURL = libraryDirectoryURL
    }

    func fileExists(atPath path: String) -> Bool {
        fileExistsCalls.append(path)
        return existingPaths.contains(path)
    }

    func currentDirectoryPath() -> String {
        currentDirectoryPathValue
    }

    func libraryDirectory() -> URL {
        libraryDirectoryURL
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        directoryContentsByPath[url.path] ?? []
    }

    func recursiveContentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        recursiveDirectoryContentsByPath[url.path] ?? []
    }

    func readFile(atPath path: String) throws -> String {
        fileContentsByPath[path] ?? ""
    }

    func readLines(atPath path: String) throws -> [String] {
        try readFile(atPath: path).components(separatedBy: .newlines)
    }

    func writeFile(_ contents: String, toPath path: String) throws {
        writeOperations.append(WriteOperation(contents: contents, path: path))
    }
}
