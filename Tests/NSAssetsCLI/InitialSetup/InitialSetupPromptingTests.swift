import Testing
@testable import NSAssetsCLI

struct InitialSetupPromptingTests {
    @Test
    func mockPrompterCanBeUsedThroughPromptingProtocol() async throws {
        let prompter: InitialSetupPrompting = MockPrompter(requiredValues: ["18.2", "Packages"])

        let requiredValue = try prompter.promptRequiredValue("iOS version")
        let optionalValue = try prompter.promptOptionalValue("Packages path")
        let result = try await prompter.performWithSpinner(prefix: "Loading") { "done" }

        #expect(requiredValue == "18.2")
        #expect(optionalValue == "Packages")
        #expect(result == "done")
    }
}
