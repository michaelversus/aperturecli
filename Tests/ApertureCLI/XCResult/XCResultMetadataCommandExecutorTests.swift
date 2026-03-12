import Foundation
import Testing
@testable import ApertureCLI

struct XCResultMetadataCommandExecutorTests {
    @Test
    func writesMetadataArtifactAtRepoRoot() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo/App/Subdir",
            existingPaths: ["/repo/.git"]
        )
        var outputLines: [String] = []
        let executor = XCResultMetadataCommandExecutor(
            fileSystem: fileSystem,
            now: { fixedDate },
            output: { outputLines.append($0) }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        let mkdir = try #require(fileSystem.createDirectoryOperations.first)
        #expect(mkdir.path == "/repo/aperture-artifacts/xcresult-metadata")
        #expect(mkdir.withIntermediateDirectories)

        let write = try #require(fileSystem.writeOperations.first)
        #expect(
            write.path
                == "/repo/aperture-artifacts/xcresult-metadata/20231114-221320-000-Snapshots.json"
        )
        let jsonData = try #require(write.contents.data(using: .utf8))
        let payload = try JSONDecoder().decode(XCResultParseMetadata.self, from: jsonData)
        #expect(payload.schemeName == "Snapshots")
        #expect(payload.projectName == "MyApp")
        #expect(payload.workspacePath == nil)
        #expect(payload.triggeredAt == "2023-11-14T22:13:20Z")
        #expect(outputLines == [write.path])
    }

    @Test
    func derivesRepoRootFromWorkspacePathInsideXcodeproj() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fileSystem = MockFileSystem(currentDirectoryPath: "/tmp/random")
        let executor = XCResultMetadataCommandExecutor(
            fileSystem: fileSystem,
            now: { fixedDate },
            output: { _ in }
        )

        try executor.run(
            schemeName: "Snapshots",
            projectName: "MyApp",
            workspacePath: "/repo/MyApp.xcodeproj/project.xcworkspace"
        )

        let mkdir = try #require(fileSystem.createDirectoryOperations.first)
        #expect(mkdir.path == "/repo/aperture-artifacts/xcresult-metadata")
    }

    @Test
    func derivesRepoRootFromWorkspacePath() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fileSystem = MockFileSystem(currentDirectoryPath: "/tmp/random")
        let executor = XCResultMetadataCommandExecutor(
            fileSystem: fileSystem,
            now: { fixedDate },
            output: { _ in }
        )

        try executor.run(
            schemeName: "Snapshots",
            projectName: "MyApp",
            workspacePath: "/repo/MyApp.xcworkspace"
        )

        let mkdir = try #require(fileSystem.createDirectoryOperations.first)
        #expect(mkdir.path == "/repo/aperture-artifacts/xcresult-metadata")
        let write = try #require(fileSystem.writeOperations.first)
        let jsonData = try #require(write.contents.data(using: .utf8))
        let payload = try JSONDecoder().decode(XCResultParseMetadata.self, from: jsonData)
        #expect(payload.workspacePath == "/repo/MyApp.xcworkspace")
    }
}
