import Foundation
import Testing
import ArgumentParser
@testable import NSAssetsCLI

struct TerminalSetupPrompterTests {
    @Test
    func writeMessageUsesProvidedOutputClosure() {
        var messages: [String] = []
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })

        prompter.writeMessage("hello")

        #expect(messages == ["hello"])
    }

    @Test
    func promptRequiredValueRejectsEmptyInputBeforeReturningTrimmedValue() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["\n", "  18.2  \n"]),
            promptWriter: { prompts.append($0) }
        )

        let value = try prompter.promptRequiredValue("iOS version")

        #expect(value == "18.2")
        #expect(prompts == ["iOS version: ", "iOS version: "])
        #expect(messages == [
            "Value cannot be empty. Please try again.",
            "✓ 18.2"
        ])
    }

    @Test
    func promptRequiredValueThrowsCleanExitWhenInputCloses() async throws {
        let prompter = TerminalSetupPrompter(
            output: { _ in },
            interactiveTerminalCheck: { false },
            readInput: { nil },
            promptWriter: { _ in }
        )

        do {
            _ = try prompter.promptRequiredValue("iOS version")
            Issue.record("Expected promptRequiredValue to exit when stdin closes.")
        } catch let error as CleanExit {
            #expect(String(describing: error) == "Input closed before setup completed.")
        }
    }

    @Test(arguments: [
        ("y\n", false, true),
        ("No\n", true, false),
        ("\n", true, true),
        ("\n", false, false)
    ])
    func promptConfirmationParsesExpectedResponses(
        input: String,
        defaultValue: Bool,
        expected: Bool
    ) async throws {
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { _ in },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: [input]),
            promptWriter: { prompts.append($0) }
        )

        let result = try prompter.promptConfirmation("Continue", defaultValue: defaultValue)

        let suffix = defaultValue ? "[Y/n]" : "[y/N]"
        #expect(result == expected)
        #expect(prompts == ["Continue \(suffix): "])
    }

    @Test
    func promptConfirmationRetriesAfterInvalidResponse() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["maybe\n", "yes\n"]),
            promptWriter: { prompts.append($0) }
        )

        let result = try prompter.promptConfirmation("Continue", defaultValue: false)

        #expect(result)
        #expect(prompts == ["Continue [y/N]: ", "Continue [y/N]: "])
        #expect(messages == ["Please answer with 'y' or 'n'."])
    }

    @Test
    func promptConfirmationThrowsCleanExitWhenInputCloses() async throws {
        let prompter = TerminalSetupPrompter(
            output: { _ in },
            interactiveTerminalCheck: { false },
            readInput: { nil },
            promptWriter: { _ in }
        )

        do {
            _ = try prompter.promptConfirmation("Continue", defaultValue: true)
            Issue.record("Expected promptConfirmation to exit when stdin closes.")
        } catch let error as CleanExit {
            #expect(String(describing: error) == "Input closed before setup completed.")
        }
    }
}

@Suite(
    .disabled("Temporarily disabled while investigating CI exit code 1 after terminal-related tests.")
)
struct TerminalSetupSchemeTests {
    @Test
    func promptSnapshotTestSchemesFallsBackToManualEntryWhenNothingIsDiscovered() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["Snapshots, FeatureSnapshots\n"]),
            promptWriter: { prompts.append($0) }
        )

        let schemes = try prompter.promptSnapshotTestSchemes(from: [])

        #expect(schemes == ["Snapshots", "FeatureSnapshots"])
        #expect(
            prompts == [
                "Provide snapshot test schemes manually (comma-separated, " +
                    "for example: MyAppSnapshots,MyFeatureSnapshots, leave empty to skip): "
            ]
        )
        #expect(messages == [
            "No .xcscheme files were discovered automatically.",
            "✓ Snapshots, FeatureSnapshots",
            "Selected schemes: Snapshots, FeatureSnapshots"
        ])
    }

    @Test
    func promptSnapshotTestSchemesAllowsEmptyManualEntryToSkipSync() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["\n"]),
            promptWriter: { prompts.append($0) }
        )

        let schemes = try prompter.promptSnapshotTestSchemes(from: [])

        #expect(schemes.isEmpty)
        #expect(
            prompts == [
                "Provide snapshot test schemes manually (comma-separated, " +
                    "for example: MyAppSnapshots,MyFeatureSnapshots, leave empty to skip): "
            ]
        )
        #expect(messages == [
            "No .xcscheme files were discovered automatically.",
            "No schemes selected. Skipping scheme post-action sync."
        ])
    }

    @Test
    func promptSnapshotTestSchemesRetriesInvalidSelectionsAndDeduplicatesResults() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["4\n", "2, snapshots, 2\n"]),
            promptWriter: { prompts.append($0) }
        )
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]

        let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)

        #expect(schemes == ["FeatureSnapshots", "Snapshots"])
        #expect(
            prompts == [
                "Select snapshot test schemes by number or name (comma-separated, or 'all', " +
                    "leave empty to skip): ",
                "Select snapshot test schemes by number or name (comma-separated, or 'all', " +
                    "leave empty to skip): "
            ]
        )
        #expect(messages == [
            "Discovered schemes:",
            "1. Snapshots",
            "2. FeatureSnapshots",
            "✓ 4",
            "Invalid selections: 4. Try again.",
            "✓ 2, snapshots, 2",
            "Selected schemes: FeatureSnapshots, Snapshots"
        ])
    }

    @Test
    func promptSnapshotTestSchemesReturnsAllDiscoveredSchemesForAllShortcut() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["all\n"]),
            promptWriter: { prompts.append($0) }
        )
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]

        let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)

        #expect(schemes == discoveredSchemes)
        #expect(
            prompts == [
                "Select snapshot test schemes by number or name (comma-separated, or 'all', " +
                    "leave empty to skip): "
            ]
        )
        #expect(messages == [
            "Discovered schemes:",
            "1. Snapshots",
            "2. FeatureSnapshots",
            "✓ all",
            "Selected schemes: Snapshots, FeatureSnapshots"
        ])
    }

    @Test
    func promptSnapshotTestSchemesAllowsEmptyTypedSelectionToSkipSync() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["\n"]),
            promptWriter: { prompts.append($0) }
        )
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]

        let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)

        #expect(schemes.isEmpty)
        #expect(
            prompts == [
                "Select snapshot test schemes by number or name (comma-separated, or 'all', " +
                    "leave empty to skip): "
            ]
        )
        #expect(messages == [
            "Discovered schemes:",
            "1. Snapshots",
            "2. FeatureSnapshots",
            "No schemes selected. Skipping scheme post-action sync."
        ])
    }

    @Test
    func promptSnapshotTestSchemesUsesInteractiveSelectionWhenTerminalSupportsIt() throws {
        var messages: [String] = []
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { true },
            cursorSchemePrompter: { schemes in
                #expect(schemes == discoveredSchemes)
                return ["FeatureSnapshots"]
            }
        )

        let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)

        #expect(schemes == ["FeatureSnapshots"])
        #expect(messages == [
            "Use arrow keys to move, space to toggle, and enter to confirm.",
            "Selected schemes: \u{001B}[32mFeatureSnapshots\u{001B}[0m"
        ])
    }

    @Test
    func promptSnapshotTestSchemesAllowsEmptyInteractiveSelectionToSkipSync() throws {
        var messages: [String] = []
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { true },
            cursorSchemePrompter: { schemes in
                #expect(schemes == discoveredSchemes)
                return []
            }
        )

        let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)

        #expect(schemes.isEmpty)
        #expect(messages == [
            "Use arrow keys to move, space to toggle, and enter to confirm.",
            "No schemes selected. Skipping scheme post-action sync."
        ])
    }

    @Test
    func performWithSpinnerRunsOperationWithoutWritingSpinnerOutputWhenTerminalIsNotInteractive() async throws {
        let spinnerRecorder = ThreadSafeStringRecorder()
        let prompter = TerminalSetupPrompter(
            output: { _ in },
            interactiveTerminalCheck: { false },
            spinnerWriter: { spinnerRecorder.append($0) }
        )

        let result = try await prompter.performWithSpinner(prefix: "Loading") { "done" }

        #expect(result == "done")
        #expect(spinnerRecorder.isEmpty)
    }

    @Test
    func performWithSpinnerRendersAndClearsSpinnerWhenTerminalIsInteractive() async throws {
        let spinnerRecorder = ThreadSafeStringRecorder()
        let prompter = TerminalSetupPrompter(
            output: { _ in },
            interactiveTerminalCheck: { true },
            spinnerWriter: { spinnerRecorder.append($0) }
        )

        let result = try await prompter.performWithSpinner(prefix: "Loading") {
            try await Task.sleep(nanoseconds: 150_000_000)
            return "done"
        }
        let stdout = spinnerRecorder.joined()

        #expect(result == "done")
        #expect(stdout.contains("\rLoading "))
        #expect(stdout.hasSuffix("\r\u{1B}[2K"))
    }
}

struct TerminalSetupPrompterOptionalPromptTests {
    @Test
    func promptOptionalValueAllowsEmptyInput() async throws {
        var messages: [String] = []
        var prompts: [String] = []
        let prompter = TerminalSetupPrompter(
            output: { messages.append($0) },
            interactiveTerminalCheck: { false },
            readInput: makeReadInput(inputs: ["\n"]),
            promptWriter: { prompts.append($0) }
        )

        let value = try prompter.promptOptionalValue("Local packages path")

        #expect(value.isEmpty)
        #expect(prompts == ["Local packages path: "])
        #expect(messages.isEmpty)
    }
}

private func makeReadInput(inputs: [String]) -> () -> String? {
    var remainingInputs = inputs
    return {
        guard !remainingInputs.isEmpty else { return nil }
        return remainingInputs.removeFirst()
    }
}

private final class ThreadSafeStringRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return values.isEmpty
    }

    func joined() -> String {
        lock.lock()
        defer { lock.unlock() }
        return values.joined()
    }
}
