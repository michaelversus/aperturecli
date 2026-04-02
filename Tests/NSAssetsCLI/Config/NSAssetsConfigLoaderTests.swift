import ArgumentParser
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
        #expect(fileSystem.fileExistsCalls == [path])
        #expect(fileSystem.readFileCalls == [path])
    }

    @Test
    func throwsCleanExitWhenConfigFileIsMissing() throws {
        let fileSystem = MockFileSystem()
        let loader = NSAssetsConfigLoader(fileSystem: fileSystem)

        do {
            _ = try loader.load(atRootPath: "/repo")
            Issue.record("Expected load(atRootPath:) to throw when the config file is missing.")
        } catch let error as CleanExit {
            #expect(
                String(describing: error)
                    == "Configuration file not found at /repo/.nsassets.json. Run `nsassets init` first."
            )
        }

        #expect(fileSystem.fileExistsCalls == ["/repo/.nsassets.json"])
        #expect(fileSystem.readFileCalls.isEmpty)
    }

    @Test(arguments: [
        ("/repo", "/repo/.nsassets.json"),
        ("/repo/", "/repo/.nsassets.json")
    ])
    func loadBuildsNSAssetsConfigPathFromRootPath(
        rootPath: String,
        expectedConfigPath: String
    ) throws {
        let fileSystem = MockFileSystem(
            existingPaths: [expectedConfigPath],
            fileContentsByPath: [
                expectedConfigPath: """
                {
                  "repoRoot": "/repo",
                  "iosVersion": "18.2",
                  "simulatorModel": "iPhone 16 Pro",
                  "xcodeVersion": "16.2",
                  "projectFileName": "MyApp.xcodeproj"
                }
                """
            ]
        )
        let loader = NSAssetsConfigLoader(fileSystem: fileSystem)

        _ = try loader.load(atRootPath: rootPath)

        #expect(fileSystem.fileExistsCalls == [expectedConfigPath])
        #expect(fileSystem.readFileCalls == [expectedConfigPath])
    }

    @Test
    func rethrowsDecodingErrorForMalformedConfigContents() {
        let path = "/repo/.nsassets.json"
        let fileSystem = MockFileSystem(
            existingPaths: [path],
            fileContentsByPath: [
                path: """
                {
                  "repoRoot":
                }
                """
            ]
        )
        let loader = NSAssetsConfigLoader(fileSystem: fileSystem)

        #expect(throws: DecodingError.self) {
            try loader.load(atRootPath: "/repo")
        }

        #expect(fileSystem.fileExistsCalls == [path])
        #expect(fileSystem.readFileCalls == [path])
    }
}
