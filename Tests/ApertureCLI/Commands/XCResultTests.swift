import Testing
@testable import ApertureCLI

struct XCResultTests {
    @Test
    func configurationDescribesXCResultCommand() {
        #expect(ApertureCLI.XCResult.configuration.commandName == "xcresult")
        #expect(ApertureCLI.XCResult.configuration.abstract == "XCResult inspection commands")
        #expect(
            ApertureCLI.XCResult.configuration.subcommands.contains {
                String(describing: $0) == String(describing: ApertureCLI.XCResult.Parse.self)
            }
        )
    }

    @Test
    func configurationDescribesParseCommand() {
        #expect(ApertureCLI.XCResult.Parse.configuration.commandName == "parse")
        #expect(
            ApertureCLI.XCResult.Parse.configuration.abstract
                == "Parse the most recent scheme xcresult in DerivedData"
        )
    }
}
