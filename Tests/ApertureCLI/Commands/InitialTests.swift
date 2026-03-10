import Testing
@testable import ApertureCLI

struct InitialTests {
    @Test
    func configurationDescribesInitCommand() {
        #expect(ApertureCLI.Initial.configuration.commandName == "init")
        #expect(ApertureCLI.Initial.configuration.abstract == "CLI setup wizard")
    }
}
