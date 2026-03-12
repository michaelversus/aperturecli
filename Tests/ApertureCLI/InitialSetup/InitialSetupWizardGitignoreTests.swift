import Foundation
import Testing
@testable import ApertureCLI

struct InitialSetupWizardGitignoreTests {
    @Test
    func appendsArtifactsDirectoryToGitignoreWhenConfirmed() async throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: [
                "/repo/MyApp.xcodeproj",
                "/repo/Packages",
                "/repo/.gitignore"
            ],
            fileContentsByPath: [
                "/repo/.gitignore": ".build/\n"
            ]
        )
        let prompter = MockPrompter(
            requiredValues: ["18.2", "iPhone 16 Pro", "16.2", "MyApp", "Packages"],
            confirmations: [true],
            selectedSchemes: ["Snapshots"]
        )
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: MockSnapshotSchemeDiscoverer(discoveredSchemes: ["Snapshots"]),
            schemePostActionSynchronizer: MockSchemePostActionSynchronizer(),
            configWriter: MockConfigWriter(configExists: false)
        )

        try await wizard.run()

        let gitignoreWrite = try #require(
            fileSystem.writeOperations.first(where: { $0.path == "/repo/.gitignore" })
        )
        #expect(gitignoreWrite.contents == ".build/\naperture-artifacts/\n")
        #expect(prompter.confirmationPrompts.contains("Add aperture-artifacts/ to .gitignore?"))
    }

    @Test
    func skipsGitignoreUpdateWhenUserDeclines() async throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: [
                "/repo/MyApp.xcodeproj",
                "/repo/Packages"
            ]
        )
        let prompter = MockPrompter(
            requiredValues: ["18.2", "iPhone 16 Pro", "16.2", "MyApp", "Packages"],
            confirmations: [false],
            selectedSchemes: ["Snapshots"]
        )
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: MockSnapshotSchemeDiscoverer(discoveredSchemes: ["Snapshots"]),
            schemePostActionSynchronizer: MockSchemePostActionSynchronizer(),
            configWriter: MockConfigWriter(configExists: false)
        )

        try await wizard.run()

        #expect(fileSystem.writeOperations.isEmpty)
        #expect(prompter.messages.contains("Skipped .gitignore update."))
    }

    @Test
    func doesNotDuplicateGitignoreEntryWhenAlreadyPresent() async throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: [
                "/repo/MyApp.xcodeproj",
                "/repo/Packages",
                "/repo/.gitignore"
            ],
            fileContentsByPath: [
                "/repo/.gitignore": ".build/\naperture-artifacts/\n"
            ]
        )
        let prompter = MockPrompter(
            requiredValues: ["18.2", "iPhone 16 Pro", "16.2", "MyApp", "Packages"],
            confirmations: [true],
            selectedSchemes: ["Snapshots"]
        )
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: MockSnapshotSchemeDiscoverer(discoveredSchemes: ["Snapshots"]),
            schemePostActionSynchronizer: MockSchemePostActionSynchronizer(),
            configWriter: MockConfigWriter(configExists: false)
        )

        try await wizard.run()

        #expect(fileSystem.writeOperations.isEmpty)
        #expect(
            prompter.messages.contains(
                "Aperture artifacts are already ignored in /repo/.gitignore"
            )
        )
    }
}
