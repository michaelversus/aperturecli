import Testing
@testable import NSAssetsCLI

struct SchemesTests {
    @Test
    func configurationDescribesSchemesCommand() {
        #expect(NSAssetsCLI.Schemes.configuration.commandName == "schemes")
        #expect(NSAssetsCLI.Schemes.configuration.abstract == "Scheme maintenance commands")
        #expect(
            NSAssetsCLI.Schemes.configuration.subcommands.contains {
                String(describing: $0) == String(describing: NSAssetsCLI.Schemes.SyncPostActions.self)
            }
        )
    }

    @Test
    func configurationDescribesSyncPostActionsCommand() {
        #expect(NSAssetsCLI.Schemes.SyncPostActions.configuration.commandName == "sync-post-actions")
        #expect(
            NSAssetsCLI.Schemes.SyncPostActions.configuration.abstract
                == "Sync managed NSAssets post-test actions into configured schemes"
        )
    }
}
