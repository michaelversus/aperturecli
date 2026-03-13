import Testing
@testable import NSAssetsCLI

struct InitialTests {
    @Test
    func configurationDescribesInitCommand() {
        #expect(NSAssetsCLI.Initial.configuration.commandName == "init")
        #expect(NSAssetsCLI.Initial.configuration.abstract == "CLI setup wizard")
    }
}
