import Foundation
import Testing
import Darwin
import ArgumentParser
@testable import NSAssetsCLI

@Suite(.serialized)
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
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })

        let stdout = try await withRedirectedStandardStreams(stdin: "\n  18.2  \n") {
            let value = try prompter.promptRequiredValue("iOS version")
            #expect(value == "18.2")
        }

        #expect(stdout == "iOS version: iOS version: ")
        #expect(messages == [
            "Value cannot be empty. Please try again.",
            "✓ 18.2"
        ])
    }

    @Test
    func promptRequiredValueThrowsCleanExitWhenInputCloses() async throws {
        let prompter = TerminalSetupPrompter(output: { _ in })

        do {
            _ = try await withRedirectedStandardStreams(stdin: "") {
                try prompter.promptRequiredValue("iOS version")
            }
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
        let prompter = TerminalSetupPrompter(output: { _ in })

        let stdout = try await withRedirectedStandardStreams(stdin: input) {
            let result = try prompter.promptConfirmation("Continue", defaultValue: defaultValue)
            #expect(result == expected)
        }

        let suffix = defaultValue ? "[Y/n]" : "[y/N]"
        #expect(stdout == "Continue \(suffix): ")
    }

    @Test
    func promptConfirmationRetriesAfterInvalidResponse() async throws {
        var messages: [String] = []
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })

        let stdout = try await withRedirectedStandardStreams(stdin: "maybe\nyes\n") {
            let result = try prompter.promptConfirmation("Continue", defaultValue: false)
            #expect(result)
        }

        #expect(stdout == "Continue [y/N]: Continue [y/N]: ")
        #expect(messages == ["Please answer with 'y' or 'n'."])
    }

    @Test
    func promptConfirmationThrowsCleanExitWhenInputCloses() async throws {
        let prompter = TerminalSetupPrompter(output: { _ in })

        do {
            _ = try await withRedirectedStandardStreams(stdin: "") {
                try prompter.promptConfirmation("Continue", defaultValue: true)
            }
            Issue.record("Expected promptConfirmation to exit when stdin closes.")
        } catch let error as CleanExit {
            #expect(String(describing: error) == "Input closed before setup completed.")
        }
    }

    @Test
    func promptSnapshotTestSchemesFallsBackToManualEntryWhenNothingIsDiscovered() async throws {
        var messages: [String] = []
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })

        let stdout = try await withRedirectedStandardStreams(stdin: "Snapshots, FeatureSnapshots\n") {
            let schemes = try prompter.promptSnapshotTestSchemes(from: [])
            #expect(schemes == ["Snapshots", "FeatureSnapshots"])
        }

        #expect(stdout.contains("Provide snapshot test schemes manually"))
        #expect(messages == [
            "No .xcscheme files were discovered automatically.",
            "✓ Snapshots, FeatureSnapshots",
            "Selected schemes: Snapshots, FeatureSnapshots"
        ])
    }

    @Test
    func promptSnapshotTestSchemesAllowsEmptyManualEntryToSkipSync() async throws {
        var messages: [String] = []
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })

        let stdout = try await withRedirectedStandardStreams(stdin: "\n") {
            let schemes = try prompter.promptSnapshotTestSchemes(from: [])
            #expect(schemes.isEmpty)
        }

        #expect(stdout.contains("Provide snapshot test schemes manually"))
        #expect(messages == [
            "No .xcscheme files were discovered automatically.",
            "No schemes selected. Skipping scheme post-action sync."
        ])
    }

    @Test
    func promptSnapshotTestSchemesRetriesInvalidSelectionsAndDeduplicatesResults() async throws {
        var messages: [String] = []
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]

        let stdout = try await withRedirectedStandardStreams(stdin: "4\n2, snapshots, 2\n") {
            let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)
            #expect(schemes == ["FeatureSnapshots", "Snapshots"])
        }

        #expect(
            stdout == "Select snapshot test schemes by number or name (comma-separated, or 'all', " +
                "leave empty to skip): Select snapshot test schemes by number or name " +
                "(comma-separated, or 'all', leave empty to skip): "
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
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]

        let stdout = try await withRedirectedStandardStreams(stdin: "all\n") {
            let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)
            #expect(schemes == discoveredSchemes)
        }

        #expect(
            stdout == "Select snapshot test schemes by number or name (comma-separated, or 'all', " +
                "leave empty to skip): "
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
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })
        let discoveredSchemes = ["Snapshots", "FeatureSnapshots"]

        let stdout = try await withRedirectedStandardStreams(stdin: "\n") {
            let schemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)
            #expect(schemes.isEmpty)
        }

        #expect(
            stdout == "Select snapshot test schemes by number or name (comma-separated, or 'all', " +
                "leave empty to skip): "
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
        let prompter = TerminalSetupPrompter(output: { _ in })

        let stdout = try await withRedirectedStandardStreams(stdin: "") {
            let result = try await prompter.performWithSpinner(prefix: "Loading") { "done" }
            #expect(result == "done")
        }

        #expect(stdout.isEmpty)
    }

    @Test
    func performWithSpinnerRendersAndClearsSpinnerWhenTerminalIsInteractive() async throws {
        let prompter = TerminalSetupPrompter(
            output: { _ in },
            interactiveTerminalCheck: { true }
        )

        let stdout = try await withRedirectedStandardStreams(stdin: "") {
            let result = try await prompter.performWithSpinner(prefix: "Loading") {
                try await Task.sleep(nanoseconds: 150_000_000)
                return "done"
            }
            #expect(result == "done")
        }

        #expect(stdout.contains("\rLoading "))
        #expect(stdout.hasSuffix("\r\u{1B}[2K"))
    }
}

@Suite(.serialized)
struct TerminalSetupPrompterOptionalPromptTests {
    @Test
    func promptOptionalValueAllowsEmptyInput() async throws {
        var messages: [String] = []
        let prompter = TerminalSetupPrompter(output: { messages.append($0) })

        let stdout = try await withRedirectedStandardStreams(stdin: "\n") {
            let value = try prompter.promptOptionalValue("Local packages path")
            #expect(value.isEmpty)
        }

        #expect(stdout == "Local packages path: ")
        #expect(messages.isEmpty)
    }
}

private func withRedirectedStandardStreams<T>(
    stdin stdinContents: String,
    operation: () async throws -> T
) async throws -> String {
    let savedStdin = dup(STDIN_FILENO)
    let savedStdout = dup(STDOUT_FILENO)
    guard savedStdin >= 0, savedStdout >= 0 else {
        throw POSIXError(.EBADF)
    }

    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()

    if let data = stdinContents.data(using: .utf8), !data.isEmpty {
        stdinPipe.fileHandleForWriting.write(data)
    }
    try stdinPipe.fileHandleForWriting.close()

    guard dup2(stdinPipe.fileHandleForReading.fileDescriptor, STDIN_FILENO) >= 0 else {
        throw POSIXError(.EBADF)
    }
    guard dup2(stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) >= 0 else {
        throw POSIXError(.EBADF)
    }
    clearerr(stdin)
    clearerr(stdout)

    defer {
        fflush(stdout)
        _ = dup2(savedStdin, STDIN_FILENO)
        _ = dup2(savedStdout, STDOUT_FILENO)
        clearerr(stdin)
        clearerr(stdout)
        close(savedStdin)
        close(savedStdout)
        try? stdinPipe.fileHandleForReading.close()
        try? stdoutPipe.fileHandleForReading.close()
    }

    _ = try await operation()

    fflush(stdout)
    _ = dup2(savedStdout, STDOUT_FILENO)
    clearerr(stdout)
    try stdoutPipe.fileHandleForWriting.close()
    let data = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
    return String(bytes: data, encoding: .utf8) ?? ""
}
