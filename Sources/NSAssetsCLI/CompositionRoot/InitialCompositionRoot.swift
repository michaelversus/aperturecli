import Foundation

struct InitialCompositionRoot {
    let fileSystem: FileSystemProvider
    let prompter: InitialSetupPrompting
    let schemeDiscoverer: SnapshotSchemeDiscovering
    let schemePostActionSynchronizer: SchemePostActionSynchronizing
    let configWriter: NSAssetsConfigWriting

    func run() async throws {
        let wizard = InitialSetupWizard(
            fileSystem: fileSystem,
            prompter: prompter,
            schemeDiscoverer: schemeDiscoverer,
            schemePostActionSynchronizer: schemePostActionSynchronizer,
            configWriter: configWriter
        )

        try await wizard.run()
    }
}
