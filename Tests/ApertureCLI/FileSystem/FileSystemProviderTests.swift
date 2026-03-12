import Foundation
import Testing
@testable import ApertureCLI

struct FileSystemProviderTests {
    @Test
    func mockFileSystemConformsToProviderContract() throws {
        let fileSystem: FileSystemProvider = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: ["/repo/file.txt"],
            fileContentsByPath: ["/repo/file.txt": "hello"]
        )

        #expect(fileSystem.currentDirectoryPath() == "/repo")
        #expect(fileSystem.fileExists(atPath: "/repo/file.txt"))
        #expect(try fileSystem.readFile(atPath: "/repo/file.txt") == "hello")
        try fileSystem.removeItem(atPath: "/repo/file.txt")
    }
}
