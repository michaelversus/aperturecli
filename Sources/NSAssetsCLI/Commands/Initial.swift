import ArgumentParser
import Foundation

extension NSAssetsCLI {
    struct Initial: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "CLI setup wizard"
        )

        func run() async throws {
            let fileSystem = FileSystem(fileManager: .default)
            let output: (String) -> Void = { message in
                Swift.print(message)
            }
            let schemeDiscoverer = SnapshotSchemeDiscoverer(fileSystem: fileSystem)
            let schemeUpdater = SchemePostActionUpdater(fileSystem: fileSystem)
            let schemeSynchronizer = SchemePostActionSynchronizer(
                schemeDiscoverer: schemeDiscoverer,
                schemeUpdater: schemeUpdater
            )
            let compositionRoot = InitialCompositionRoot(
                fileSystem: fileSystem,
                prompter: TerminalSetupPrompter(output: output),
                schemeDiscoverer: schemeDiscoverer,
                schemePostActionSynchronizer: schemeSynchronizer,
                configWriter: NSAssetsConfigWriter(fileSystem: fileSystem)
            )
            try await compositionRoot.run()
        }
    }
}
