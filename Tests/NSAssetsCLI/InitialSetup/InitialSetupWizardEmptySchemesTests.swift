import Foundation
import Testing
@testable import NSAssetsCLI

struct InitialSetupWizardEmptySchemesTests {
    @Test
    func skipsSchemeSyncWhenNoSchemesAreSelected() async throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: [
                "/repo/MyApp.xcodeproj",
                "/repo/Packages"
            ]
        )
        let prompter = MockPrompter(
            requiredValues: [
                "18.2",
                "iPhone 16 Pro",
                "16.2",
                "MyApp",
                "Packages"
            ],
            confirmations: [true],
            selectedSchemes: []
        )
        let discoverer = MockSnapshotSchemeDiscoverer(discoveredSchemes: ["Snapshots"])
        let synchronizer = MockSchemePostActionSynchronizer()
        let configWriter = MockConfigWriter(configExists: false)
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: discoverer,
            schemePostActionSynchronizer: synchronizer,
            configWriter: configWriter
        )

        try await wizard.run()

        let writtenConfig = try #require(configWriter.writtenConfig)
        #expect(writtenConfig.snapshotTestSchemes.isEmpty)
        #expect(synchronizer.callCount == 0)
        #expect(
            prompter.messages.contains(
                "No schemes selected. Skipping scheme post-action sync."
            )
        )
    }
}
