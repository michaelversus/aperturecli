import Testing
@testable import ApertureCLI

struct SchemesTests {
    @Test
    func configurationDescribesSchemesCommand() {
        #expect(ApertureCLI.Schemes.configuration.commandName == "schemes")
        #expect(ApertureCLI.Schemes.configuration.abstract == "Scheme maintenance commands")
        #expect(
            ApertureCLI.Schemes.configuration.subcommands.contains {
                String(describing: $0) == String(describing: ApertureCLI.Schemes.SyncPostActions.self)
            }
        )
    }

    @Test
    func configurationDescribesSyncPostActionsCommand() {
        #expect(ApertureCLI.Schemes.SyncPostActions.configuration.commandName == "sync-post-actions")
        #expect(
            ApertureCLI.Schemes.SyncPostActions.configuration.abstract
                == "Sync managed Aperture post-test actions into configured schemes"
        )
    }
}
