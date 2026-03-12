import Testing
@testable import ApertureCLI

struct TestTests {
    @Test
    func configurationDescribesTestCommand() {
        #expect(ApertureCLI.Test.configuration.commandName == "test")
        #expect(ApertureCLI.Test.configuration.abstract == "Test lifecycle commands")
        #expect(
            ApertureCLI.Test.configuration.subcommands.contains {
                String(describing: $0) == String(describing: ApertureCLI.Test.Executed.self)
            }
        )
    }

    @Test
    func configurationDescribesExecutedCommand() {
        #expect(ApertureCLI.Test.Executed.configuration.commandName == "executed")
        #expect(
            ApertureCLI.Test.Executed.configuration.abstract
                == "Emit test-executed metadata for deferred xcresult processing"
        )
    }
}
