import Testing
@testable import NSAssetsCLI

struct NSAssetsConfigLoaderTests {
    @Test
    func loadsConfigFromNSAssetsFile() throws {
        let path = "/repo/.nsassets.json"
        let fileSystem = MockFileSystem(
            existingPaths: [path],
            fileContentsByPath: [
                path: """
                {
                  "repoRoot": "/repo",
                  "iosVersion": "18.2",
                  "simulatorModel": "iPhone 16 Pro",
                  "xcodeVersion": "16.2",
                  "projectFileName": "MyApp.xcodeproj",
                  "spmPackagesContainerPath": "Packages",
                  "snapshotTestSchemes": ["Snapshots"]
                }
                """
            ]
        )
        let loader = NSAssetsConfigLoader(fileSystem: fileSystem)

        let config = try loader.load(atRootPath: "/repo")

        #expect(config.repoRoot == "/repo")
        #expect(config.snapshotTestSchemes == ["Snapshots"])
    }

    @Test
    func throwsCleanExitWhenConfigFileIsMissing() throws {
        let loader = NSAssetsConfigLoader(fileSystem: MockFileSystem())

        #expect(throws: (any Error).self) {
            try loader.load(atRootPath: "/repo")
        }
    }
}
