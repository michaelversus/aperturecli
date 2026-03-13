import Foundation
@testable import NSAssetsCLI

final class MockFileSystem: FileSystemProvider {
    struct RemoveItemOperation {
        let path: String
    }

    struct WriteOperation {
        let contents: String
        let path: String
    }

    struct CreateDirectoryOperation {
        let path: String
        let withIntermediateDirectories: Bool
    }

    let currentDirectoryPathValue: String
    let fileExistsResults: [String: Bool]
    let existingPaths: Set<String>
    let directoryContentsByPath: [String: [URL]]
    let recursiveDirectoryContentsByPath: [String: [URL]]
    let fileContentsByPath: [String: String]
    let libraryDirectoryURL: URL
    let removeItemErrorByPath: [String: Error]

    private(set) var fileExistsCalls: [String] = []
    private(set) var removeItemOperations: [RemoveItemOperation] = []
    private(set) var writeOperations: [WriteOperation] = []
    private(set) var createDirectoryOperations: [CreateDirectoryOperation] = []

    init(
        currentDirectoryPath: String = "/repo",
        fileExistsResults: [String: Bool] = [:],
        existingPaths: Set<String> = [],
        directoryContentsByPath: [String: [URL]] = [:],
        recursiveDirectoryContentsByPath: [String: [URL]] = [:],
        fileContentsByPath: [String: String] = [:],
        removeItemErrorByPath: [String: Error] = [:],
        libraryDirectoryURL: URL = URL(fileURLWithPath: "/tmp", isDirectory: true)
    ) {
        self.currentDirectoryPathValue = currentDirectoryPath
        self.fileExistsResults = fileExistsResults
        self.existingPaths = existingPaths
        self.directoryContentsByPath = directoryContentsByPath
        self.recursiveDirectoryContentsByPath = recursiveDirectoryContentsByPath
        self.fileContentsByPath = fileContentsByPath
        self.removeItemErrorByPath = removeItemErrorByPath
        self.libraryDirectoryURL = libraryDirectoryURL
    }

    convenience init(
        currentDirectoryPath: String = "/repo",
        fileExistsResults: [String: Bool] = [:],
        libraryDirectoryURL: URL = URL(fileURLWithPath: "/tmp", isDirectory: true),
        contentsOfDirectoryResults: [URL: [URL]] = [:],
        recursiveContentsOfDirectoryResults: [URL: [URL]] = [:],
        fileContentsByPath: [String: String] = [:],
        removeItemErrorByPath: [String: Error] = [:]
    ) {
        self.init(
            currentDirectoryPath: currentDirectoryPath,
            fileExistsResults: fileExistsResults,
            existingPaths: Set(fileExistsResults.compactMap { key, value in value ? key : nil }),
            directoryContentsByPath: Dictionary(
                uniqueKeysWithValues: contentsOfDirectoryResults.map { ($0.key.path, $0.value) }
            ),
            recursiveDirectoryContentsByPath: Dictionary(
                uniqueKeysWithValues: recursiveContentsOfDirectoryResults.map { ($0.key.path, $0.value) }
            ),
            fileContentsByPath: fileContentsByPath,
            removeItemErrorByPath: removeItemErrorByPath,
            libraryDirectoryURL: libraryDirectoryURL
        )
    }

    func fileExists(atPath path: String) -> Bool {
        fileExistsCalls.append(path)
        if let result = fileExistsResults[path] {
            return result
        }
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

    func removeItem(atPath path: String) throws {
        removeItemOperations.append(RemoveItemOperation(path: path))
        if let error = removeItemErrorByPath[path] {
            throw error
        }
    }

    func createDirectory(atPath path: String, withIntermediateDirectories: Bool) throws {
        createDirectoryOperations.append(
            CreateDirectoryOperation(
                path: path,
                withIntermediateDirectories: withIntermediateDirectories
            )
        )
    }
}
