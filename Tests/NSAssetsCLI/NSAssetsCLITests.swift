import Testing
@testable import NSAssetsCLI

struct NSAssetsCLITests {
    @Test
    func configurationUsesInitialAsDefaultSubcommand() {
        #expect(NSAssetsCLI.configuration.abstract == "CLI bridge for NSAssets Studio app and Xcode")
        #expect(NSAssetsCLI.configuration.version == version)
        #expect(
            NSAssetsCLI.configuration.subcommands.contains {
                String(describing: $0) == String(describing: NSAssetsCLI.Initial.self)
            }
        )
        #expect(
            NSAssetsCLI.configuration.subcommands.contains {
                String(describing: $0) == String(describing: NSAssetsCLI.Schemes.self)
            }
        )
        #expect(
            NSAssetsCLI.configuration.subcommands.contains {
                String(describing: $0) == String(describing: NSAssetsCLI.XCResult.self)
            }
        )
        #expect(
            String(describing: NSAssetsCLI.configuration.defaultSubcommand)
                == String(describing: Optional(NSAssetsCLI.Initial.self))
        )
    }
}
