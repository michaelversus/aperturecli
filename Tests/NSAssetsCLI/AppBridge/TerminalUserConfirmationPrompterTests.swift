import Foundation
import Testing
@testable import NSAssetsCLI

struct TerminalUserConfirmationPrompterTests {
    @Test(arguments: [
        (true, true),
        (false, false)
    ])
    func canPromptUserReflectsTerminalInteractivity(
        interactiveTerminal: Bool,
        expected: Bool
    ) {
        let prompter = TerminalUserConfirmationPrompter(
            output: { _ in },
            interactiveTerminalCheck: { interactiveTerminal }
        )

        #expect(prompter.canPromptUser() == expected)
    }

    @Test(arguments: [
        ("y\n", false, true),
        ("No\n", true, false),
        ("\n", true, true),
        ("\n", false, false)
    ])
    func promptToOpenAppParsesExpectedResponses(
        input: String,
        defaultValue: Bool,
        expected: Bool
    ) throws {
        var prompts: [String] = []
        let prompter = TerminalUserConfirmationPrompter(
            output: { _ in },
            readInput: makeReadInput(inputs: [input]),
            promptWriter: { prompts.append($0) }
        )

        let result = try prompter.promptToOpenApp(
            appName: AppBridgeConstants.appDisplayName,
            defaultValue: defaultValue
        )

        let suffix = defaultValue ? "[Y/n]" : "[y/N]"
        #expect(result == expected)
        #expect(prompts == ["Open \(AppBridgeConstants.appDisplayName) now? \(suffix): "])
    }

    @Test
    func promptToOpenAppRetriesAfterInvalidResponse() throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalUserConfirmationPrompter(
            output: { messages.append($0) },
            readInput: makeReadInput(inputs: ["maybe\n", "yes\n"]),
            promptWriter: { prompts.append($0) }
        )

        let result = try prompter.promptToOpenApp(
            appName: AppBridgeConstants.appDisplayName,
            defaultValue: false
        )

        #expect(
            prompts ==
                [
                    "Open \(AppBridgeConstants.appDisplayName) now? [y/N]: ",
                    "Open \(AppBridgeConstants.appDisplayName) now? [y/N]: "
                ]
        )
        #expect(result)
        #expect(messages == ["Please answer with 'y' or 'n'."])
    }

    @Test
    func promptToOpenAppThrowsUserCancelledWhenInputCloses() throws {
        var prompts: [String] = []
        let prompter = TerminalUserConfirmationPrompter(
            output: { _ in },
            readInput: { nil },
            promptWriter: { prompts.append($0) }
        )

        do {
            _ = try prompter.promptToOpenApp(
                appName: AppBridgeConstants.appDisplayName,
                defaultValue: true
            )
            Issue.record("Expected promptToOpenApp to throw when stdin closes.")
        } catch {
            let nsError = error as NSError
            #expect(nsError.domain == NSCocoaErrorDomain)
            #expect(nsError.code == CocoaError.Code.userCancelled.rawValue)
        }

        #expect(prompts == ["Open \(AppBridgeConstants.appDisplayName) now? [Y/n]: "])
    }
}

private func makeReadInput(inputs: [String]) -> () -> String? {
    var remainingInputs = inputs
    return {
        guard !remainingInputs.isEmpty else { return nil }
        return remainingInputs.removeFirst()
    }
}
