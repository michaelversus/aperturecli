import Foundation

struct InitialCompositionRoot {
    let fileSystem: FileSystemProvider
    let prompter: InitialSetupPrompting
    let schemeDiscoverer: SnapshotSchemeDiscovering
    let configWriter: ApertureConfigWriting

    func run() async throws {
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: schemeDiscoverer,
            configWriter: configWriter
        )

        try await wizard.run()
    }
}
