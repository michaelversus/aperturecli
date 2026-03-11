import Testing
@testable import ApertureCLI
import Foundation

struct XCResultParseCommandExecutorTests {
    @Test
    func writesArtifactJSONAtRepoRoot() throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo/App/Subdir",
            existingPaths: ["/repo/.git"]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        var outputLines: [String] = []
        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            output: { outputLines.append($0) }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        #expect(resolver.callCount == 1)
        #expect(resolver.receivedSchemeName == "Snapshots")
        #expect(resolver.receivedProjectName == "MyApp")
        let mkdir = try #require(fileSystem.createDirectoryOperations.first)
        #expect(mkdir.path == "/repo/aperture-artifacts/xcresults")
        #expect(mkdir.withIntermediateDirectories)

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.path == "/repo/aperture-artifacts/xcresults/Snapshots.json")
        let jsonData = try #require(write.contents.data(using: .utf8))
        let payload = try #require(JSONSerialization.jsonObject(with: jsonData) as? [String: String])
        #expect(payload == ["Snapshots": "/tmp/result.xcresult"])
        #expect(outputLines == ["/repo/aperture-artifacts/xcresults/Snapshots.json"])
    }

    @Test
    func rethrowsResolverError() throws {
        let fileSystem = MockFileSystem(currentDirectoryPath: "/repo")
        let resolver = MockXCResultPathResolver(result: .failure(XCResultPathResolverError.noXCResultFiles(path: "/tmp")))
        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            output: { _ in }
        )

        #expect(throws: XCResultPathResolverError.noXCResultFiles(path: "/tmp")) {
            try executor.run(schemeName: "Snapshots", projectName: "MyApp")
        }
    }
}
