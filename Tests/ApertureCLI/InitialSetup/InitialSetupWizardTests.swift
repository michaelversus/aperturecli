import Foundation
import Testing
@testable import ApertureCLI

struct InitialSetupWizardTests {
    @Test
    func cancelsWhenExistingConfigShouldNotBeReplaced() async throws {
        let fileSystem = MockFileSystem(currentDirectoryPath: "/repo")
        let prompter = MockPrompter(confirmations: [false])
        let discoverer = MockSnapshotSchemeDiscoverer()
        let synchronizer = MockSchemePostActionSynchronizer()
        let configWriter = MockConfigWriter(configExists: true)
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: discoverer,
            schemePostActionSynchronizer: synchronizer,
            configWriter: configWriter
        )

        do {
            try await wizard.run()
            Issue.record("Expected setup cancellation.")
        } catch {
            #expect(configWriter.writeCallCount == 0)
            #expect(discoverer.callCount == 0)
            #expect(synchronizer.callCount == 0)
            #expect(prompter.promptedValues.isEmpty)
            #expect(prompter.messages.contains("Keeping existing configuration. Setup cancelled."))
        }
    }

    @Test
    func replacesExistingConfigAndContinuesSetup() async throws {
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
            selectedSchemes: ["Snapshots"]
        )
        let discoverer = MockSnapshotSchemeDiscoverer(discoveredSchemes: ["Snapshots"])
        let synchronizer = MockSchemePostActionSynchronizer(
            result: SchemePostActionSyncResult(
                matchedSchemeNames: ["Snapshots"],
                updatedSchemeFilePaths: ["/repo/MyApp.xcodeproj/xcshareddata/xcschemes/Snapshots.xcscheme"],
                missingSelectedSchemeNames: []
            )
        )
        let configWriter = MockConfigWriter(configExists: true)
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: discoverer,
            schemePostActionSynchronizer: synchronizer,
            configWriter: configWriter
        )

        try await wizard.run()

        #expect(prompter.messages.contains("Replacing existing configuration."))
        #expect(prompter.messages.contains("Saved configuration to /repo/.aperture.json"))
        #expect(discoverer.callCount == 1)
        #expect(synchronizer.callCount == 1)
        #expect(configWriter.writeCallCount == 1)
    }

    @Test
    func normalizesProjectNameAndWritesCollectedConfig() async throws {
        let context = makeNormalizedSetupContext()

        try await context.wizard.run()

        try assertNormalizedSetupResult(context)
    }

    @Test
    func keepsProjectFileNameWhenInputAlreadyIncludesExtension() async throws {
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
                "MyApp.xcodeproj",
                "Packages"
            ],
            selectedSchemes: ["Snapshots"]
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
        #expect(writtenConfig.projectFileName == "MyApp.xcodeproj")
        #expect(discoverer.receivedProjectFileName == "MyApp.xcodeproj")
    }

    @Test
    func preservesAbsoluteProjectAndPackagesPaths() async throws {
        let projectPath = "/tmp/MyApp.xcodeproj"
        let packagesPath = "/tmp/Packages"
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: [
                projectPath,
                packagesPath
            ]
        )
        let prompter = MockPrompter(
            requiredValues: [
                "18.2",
                "iPhone 16 Pro",
                "16.2",
                projectPath,
                packagesPath
            ],
            selectedSchemes: ["Snapshots"]
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
        #expect(writtenConfig.projectFileName == projectPath)
        #expect(writtenConfig.spmPackagesContainerPath == packagesPath)
        #expect(discoverer.receivedProjectFileName == projectPath)
        #expect(discoverer.receivedSPMPackagesPath == packagesPath)
        #expect(fileSystem.fileExistsCalls.contains(projectPath))
        #expect(fileSystem.fileExistsCalls.contains(packagesPath))
        #expect(!fileSystem.fileExistsCalls.contains("/repo\(projectPath)"))
        #expect(!fileSystem.fileExistsCalls.contains("/repo\(packagesPath)"))
    }

    @Test
    func doesNotWriteConfigWhenSchemeSyncFails() async throws {
        struct SyncFailure: Error {}

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
            selectedSchemes: ["Snapshots"]
        )
        let discoverer = MockSnapshotSchemeDiscoverer(discoveredSchemes: ["Snapshots"])
        let synchronizer = MockSchemePostActionSynchronizer(error: SyncFailure())
        let configWriter = MockConfigWriter(configExists: false)
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: discoverer,
            schemePostActionSynchronizer: synchronizer,
            configWriter: configWriter
        )

        do {
            try await wizard.run()
            Issue.record("Expected sync failure.")
        } catch is SyncFailure {
            #expect(synchronizer.callCount == 1)
            #expect(configWriter.writeCallCount == 0)
        }
    }

}

private struct NormalizedSetupContext {
    let fileSystem: MockFileSystem
    let prompter: MockPrompter
    let discoverer: MockSnapshotSchemeDiscoverer
    let synchronizer: MockSchemePostActionSynchronizer
    let configWriter: MockConfigWriter
    let wizard: InitialSetupWizard
}

private func makeNormalizedSetupContext() -> NormalizedSetupContext {
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
            "MissingProject",
            "MyApp",
            "MissingPackages",
            "Packages"
        ],
        selectedSchemes: ["Snapshots"]
    )
    let discoverer = MockSnapshotSchemeDiscoverer(discoveredSchemes: ["Snapshots"])
    let synchronizer = MockSchemePostActionSynchronizer(
        result: SchemePostActionSyncResult(
            matchedSchemeNames: ["Snapshots"],
            updatedSchemeFilePaths: ["/repo/MyApp.xcodeproj/xcshareddata/xcschemes/Snapshots.xcscheme"],
            missingSelectedSchemeNames: []
        )
    )
    let configWriter = MockConfigWriter(configExists: false)
    let wizard = InitialSetupWizard(
        fileSystem: fileSystem,
        prompter: prompter,
        schemeDiscoverer: discoverer,
        schemePostActionSynchronizer: synchronizer,
        configWriter: configWriter
    )

    return NormalizedSetupContext(
        fileSystem: fileSystem,
        prompter: prompter,
        discoverer: discoverer,
        synchronizer: synchronizer,
        configWriter: configWriter,
        wizard: wizard
    )
}

private func assertNormalizedSetupResult(_ context: NormalizedSetupContext) throws {
    let writtenConfig = try #require(context.configWriter.writtenConfig)
    #expect(writtenConfig.repoRoot == "/repo")
    #expect(writtenConfig.iosVersion == "18.2")
    #expect(writtenConfig.simulatorModel == "iPhone 16 Pro")
    #expect(writtenConfig.xcodeVersion == "16.2")
    #expect(writtenConfig.projectFileName == "MyApp.xcodeproj")
    #expect(writtenConfig.spmPackagesContainerPath == "Packages")
    #expect(writtenConfig.snapshotTestSchemes == ["Snapshots"])
    #expect(context.discoverer.receivedProjectFileName == "MyApp.xcodeproj")
    #expect(context.discoverer.receivedSPMPackagesPath == "Packages")
    #expect(context.synchronizer.receivedProjectFileName == "MyApp.xcodeproj")
    #expect(context.synchronizer.receivedSPMPackagesPath == "Packages")
    #expect(context.synchronizer.receivedSelectedSchemeNames == ["Snapshots"])
    #expect(
        context.prompter.messages.contains(
            "Project file does not exist: MissingProject.xcodeproj. Please try again."
        )
    )
    #expect(context.prompter.messages.contains("Path does not exist: MissingPackages. Please try again."))
    #expect(context.prompter.messages.contains("Matched schemes: 1"))
    #expect(context.prompter.messages.contains("Updated scheme files: 1"))
    #expect(context.prompter.messages.contains("Updated scheme file paths:"))
    #expect(
        context.prompter.messages.contains(
            " - /repo/MyApp.xcodeproj/xcshareddata/xcschemes/Snapshots.xcscheme"
        )
    )
    #expect(context.prompter.messages.contains("Saved configuration to /repo/.aperture.json"))
    #expect(context.fileSystem.fileExistsCalls.contains("/repo/MyApp.xcodeproj"))
}
