import Testing
@testable import ApertureCLI

struct InitialSetupPromptingTests {
    @Test
    func mockPrompterCanBeUsedThroughPromptingProtocol() async throws {
        let prompter: InitialSetupPrompting = MockPrompter(requiredValues: ["18.2"])

        let value = try prompter.promptRequiredValue("iOS version")
        let result = try await prompter.performWithSpinner(prefix: "Loading") { "done" }

        #expect(value == "18.2")
        #expect(result == "done")
    }
}
