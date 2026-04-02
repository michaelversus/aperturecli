import ArgumentParser
import Testing
@testable import NSAssetsCLI

struct InitialTests {
    @Test
    func configurationDescribesInitCommand() {
        #expect(NSAssetsCLI.Initial.configuration.commandName == "init")
        #expect(NSAssetsCLI.Initial.configuration.abstract == "CLI setup wizard")
    }

    @Test(arguments: [
        [],
        ["init"]
    ])
    func parseRoutesToInitialCommand(arguments: [String]) throws {
        let command = try NSAssetsCLI.parseAsRoot(arguments)

        #expect(command is NSAssetsCLI.Initial)
    }

    @Test
    func parseRejectsUnexpectedInitialArguments() {
        #expect(throws: Error.self) {
            _ = try NSAssetsCLI.parseAsRoot(["init", "unexpected"])
        }
    }
}
