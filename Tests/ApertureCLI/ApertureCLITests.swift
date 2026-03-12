import Testing
@testable import ApertureCLI

struct ApertureCLITests {
    @Test
    func configurationUsesInitialAsDefaultSubcommand() {
        #expect(ApertureCLI.configuration.abstract == "CLI bridge for Aperture Studio app and Xcode")
        #expect(ApertureCLI.configuration.version == version)
        #expect(
            ApertureCLI.configuration.subcommands.contains {
                String(describing: $0) == String(describing: ApertureCLI.Initial.self)
            }
        )
        #expect(
            ApertureCLI.configuration.subcommands.contains {
                String(describing: $0) == String(describing: ApertureCLI.Schemes.self)
            }
        )
        #expect(
            ApertureCLI.configuration.subcommands.contains {
                String(describing: $0) == String(describing: ApertureCLI.Test.self)
            }
        )
        #expect(
            ApertureCLI.configuration.subcommands.contains {
                String(describing: $0) == String(describing: ApertureCLI.XCResult.self)
            }
        )
        #expect(
            String(describing: ApertureCLI.configuration.defaultSubcommand)
                == String(describing: Optional(ApertureCLI.Initial.self))
        )
    }
}
