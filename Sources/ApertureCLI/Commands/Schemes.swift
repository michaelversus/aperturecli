import ArgumentParser
import Foundation

extension ApertureCLI {
    struct Schemes: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "schemes",
            abstract: "Scheme maintenance commands",
            subcommands: [SyncPostActions.self]
        )
    }
}

extension ApertureCLI.Schemes {
    struct SyncPostActions: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sync-post-actions",
            abstract: "Sync managed Aperture post-test actions into configured schemes"
        )

        func run() async throws {
            let fileSystem = FileSystem(fileManager: .default)
            let schemeDiscoverer = SnapshotSchemeDiscoverer(fileSystem: fileSystem)
            let schemeUpdater = SchemePostActionUpdater(fileSystem: fileSystem)
            let synchronizer = SchemePostActionSynchronizer(
                schemeDiscoverer: schemeDiscoverer,
                schemeUpdater: schemeUpdater
            )
            let executor = SyncPostActionsCommandExecutor(
                fileSystem: fileSystem,
                configLoader: ApertureConfigLoader(fileSystem: fileSystem),
                synchronizer: synchronizer,
                output: { message in Swift.print(message) }
            )

            try executor.run()
        }
    }
}
