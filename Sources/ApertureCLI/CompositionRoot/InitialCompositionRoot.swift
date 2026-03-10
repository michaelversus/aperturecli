import Foundation

struct InitialCompositionRoot {
    let fileSystem: FileSystemProvider
    let prompter: InitialSetupPrompting
    let schemeDiscoverer: SnapshotSchemeDiscovering
    let configWriter: ApertureConfigWriting

    init(
        fileSystem: FileSystemProvider,
        prompter: InitialSetupPrompting,
        schemeDiscoverer: SnapshotSchemeDiscovering,
        configWriter: ApertureConfigWriting
    ) {
        self.fileSystem = fileSystem
        self.prompter = prompter
        self.schemeDiscoverer = schemeDiscoverer
        self.configWriter = configWriter
    }

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
