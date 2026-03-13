import Testing
@testable import NSAssetsCLI

struct InitialCompositionRootTests {
    @Test
    func runBuildsWizardWithInjectedDependencies() async throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: [
            "/repo/MyApp.xcodeproj",
            "/repo/Packages"
            ]
        )
        let prompter = MockPrompter(
            requiredValues: ["18.2", "iPhone 16 Pro", "16.2", "MyApp", "Packages"],
            confirmations: [true],
            selectedSchemes: ["FeatureSnapshots"]
        )
        let schemeDiscoverer = MockSnapshotSchemeDiscoverer(discoveredSchemes: ["FeatureSnapshots"])
        let schemeSynchronizer = MockSchemePostActionSynchronizer()
        let configWriter = MockConfigWriter(configExists: false)

        let compositionRoot = InitialCompositionRoot(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: schemeDiscoverer,
            schemePostActionSynchronizer: schemeSynchronizer,
            configWriter: configWriter
        )

        try await compositionRoot.run()

        #expect(schemeDiscoverer.callCount == 1)
        #expect(schemeDiscoverer.receivedRepoRoot == "/repo")
        #expect(schemeDiscoverer.receivedProjectFileName == "MyApp.xcodeproj")
        #expect(schemeDiscoverer.receivedSPMPackagesPath == "Packages")
        #expect(schemeSynchronizer.callCount == 1)
        #expect(configWriter.writeCallCount == 1)
        #expect(configWriter.writtenRootPath == "/repo")
        #expect(configWriter.writtenConfig?.snapshotTestSchemes == ["FeatureSnapshots"])
    }
}
