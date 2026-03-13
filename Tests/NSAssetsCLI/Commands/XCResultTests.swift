import Testing
@testable import NSAssetsCLI

struct XCResultTests {
    @Test
    func configurationDescribesXCResultCommand() {
        #expect(NSAssetsCLI.XCResult.configuration.commandName == "xcresult")
        #expect(NSAssetsCLI.XCResult.configuration.abstract == "XCResult inspection commands")
        #expect(
            NSAssetsCLI.XCResult.configuration.subcommands.contains {
                String(describing: $0) == String(describing: NSAssetsCLI.XCResult.Parse.self)
            }
        )
    }

    @Test
    func configurationDescribesParseCommand() {
        #expect(NSAssetsCLI.XCResult.Parse.configuration.commandName == "parse")
        #expect(
            NSAssetsCLI.XCResult.Parse.configuration.abstract
                == "Parse the most recent scheme xcresult in DerivedData"
        )
    }
}
