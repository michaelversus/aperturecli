import Testing
@testable import ApertureCLI

struct SyncPostActionsCommandExecutorTests {
    @Test
    func loadsConfigAndCallsSynchronizer() throws {
        let fileSystem = MockFileSystem(currentDirectoryPath: "/repo")
        let loader = MockApertureConfigLoader(
            config: ApertureConfig(
                repoRoot: "/repo",
                iosVersion: "18.2",
                simulatorModel: "iPhone 16 Pro",
                xcodeVersion: "16.2",
                projectFileName: "MyApp.xcodeproj",
                spmPackagesContainerPath: "Packages",
                snapshotTestSchemes: ["Snapshots"]
            )
        )
        let synchronizer = MockSchemePostActionSynchronizer(
            result: SchemePostActionSyncResult(
                matchedSchemeNames: ["Snapshots"],
                updatedSchemeFilePaths: ["/repo/MyApp.xcodeproj/xcshareddata/xcschemes/Snapshots.xcscheme"],
                missingSelectedSchemeNames: ["Missing"]
            )
        )
        var outputLines: [String] = []
        let executor = SyncPostActionsCommandExecutor(
            fileSystem: fileSystem,
            configLoader: loader,
            synchronizer: synchronizer,
            output: { outputLines.append($0) }
        )

        try executor.run()

        #expect(loader.loadCallCount == 1)
        #expect(loader.receivedRootPath == "/repo")
        #expect(synchronizer.callCount == 1)
        #expect(synchronizer.receivedRepoRoot == "/repo")
        #expect(synchronizer.receivedProjectFileName == "MyApp.xcodeproj")
        #expect(synchronizer.receivedProjectName == "MyApp")
        #expect(synchronizer.receivedSPMPackagesPath == "Packages")
        #expect(synchronizer.receivedSelectedSchemeNames == ["Snapshots"])
        #expect(outputLines.contains("Matched schemes: 1"))
        #expect(outputLines.contains("Updated scheme files: 1"))
        #expect(outputLines.contains("Missing selected schemes: 1"))
        #expect(outputLines.contains("Updated scheme file paths:"))
        #expect(
            outputLines.contains(" - /repo/MyApp.xcodeproj/xcshareddata/xcschemes/Snapshots.xcscheme")
        )
        #expect(outputLines.contains("Skipped missing schemes: Missing"))
    }
}
