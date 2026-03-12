import Foundation
import ArgumentParser
import Darwin

struct TerminalSetupPrompter: InitialSetupPrompting {
    let output: (String) -> Void
    private let interactiveTerminalCheck: () -> Bool
    private let cursorSchemePrompter: ([String]) throws -> [String]

    init(
        output: @escaping (String) -> Void,
        interactiveTerminalCheck: @escaping () -> Bool = {
            isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
        },
        cursorSchemePrompter: @escaping ([String]) throws -> [String] = { schemes in
            try CursorMultiSelect(options: schemes).run()
        }
    ) {
        self.output = output
        self.interactiveTerminalCheck = interactiveTerminalCheck
        self.cursorSchemePrompter = cursorSchemePrompter
    }

    func writeMessage(_ message: String) {
        output(message)
    }

    func promptRequiredValue(_ prompt: String) throws -> String {
        while true {
            ensureCanonicalTerminalModeIfTTY()
            Self.writeToStdout("\(prompt): ")
            guard let rawInput = readLine() else {
                throw CleanExit.message("Input closed before setup completed.")
            }

            let value = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                output("✓ \(green(value))")
                return value
            }

            output("Value cannot be empty. Please try again.")
        }
    }

    func promptOptionalValue(_ prompt: String) throws -> String {
        ensureCanonicalTerminalModeIfTTY()
        Self.writeToStdout("\(prompt): ")
        guard let rawInput = readLine() else {
            throw CleanExit.message("Input closed before setup completed.")
        }

        let value = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            output("✓ \(green(value))")
        }
        return value
    }

    func promptConfirmation(_ prompt: String, defaultValue: Bool) throws -> Bool {
        let promptSuffix = defaultValue ? "[Y/n]" : "[y/N]"

        while true {
            ensureCanonicalTerminalModeIfTTY()
            Self.writeToStdout("\(prompt) \(promptSuffix): ")
            guard let rawInput = readLine() else {
                throw CleanExit.message("Input closed before setup completed.")
            }

            let value = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch value {
            case "y", "yes":
                return true
            case "n", "no":
                return false
            case "":
                return defaultValue
            default:
                output("Please answer with 'y' or 'n'.")
            }
        }
    }

    func promptSnapshotTestSchemes(from discoveredSchemes: [String]) throws -> [String] {
        if discoveredSchemes.isEmpty {
            output("No .xcscheme files were discovered automatically.")
            let manualSchemes = try promptOptionalListValue(
                "Provide snapshot test schemes manually (comma-separated, " +
                    "for example: MyAppSnapshots,MyFeatureSnapshots, leave empty to skip)"
            )
            if manualSchemes.isEmpty {
                output("No schemes selected. Skipping scheme post-action sync.")
                return []
            }
            output("Selected schemes: \(manualSchemes.map(green).joined(separator: ", "))")
            return manualSchemes
        }

        if supportsInteractiveTerminal() {
            output("Use arrow keys to move, space to toggle, and enter to confirm.")
            let selectedSchemes = try promptSnapshotTestSchemesWithCursor(from: discoveredSchemes)
            if selectedSchemes.isEmpty {
                output("No schemes selected. Skipping scheme post-action sync.")
                return []
            }
            output("Selected schemes: \(selectedSchemes.map(green).joined(separator: ", "))")
            return selectedSchemes
        }

        return try promptSnapshotTestSchemesFromDiscoveredList(discoveredSchemes)
    }

    private func promptSnapshotTestSchemesFromDiscoveredList(_ discoveredSchemes: [String]) throws -> [String] {
        output("Discovered schemes:")
        for (index, scheme) in discoveredSchemes.enumerated() {
            output("\(index + 1). \(scheme)")
        }

        while true {
            let rawSelection = try promptOptionalValue(
                "Select snapshot test schemes by number or name (comma-separated, or 'all', leave empty to skip)"
            )
            let trimmedSelection = rawSelection.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSelection.isEmpty {
                output("No schemes selected. Skipping scheme post-action sync.")
                return []
            }

            if trimmedSelection.caseInsensitiveCompare("all") == .orderedSame {
                output("Selected schemes: \(discoveredSchemes.map(green).joined(separator: ", "))")
                return discoveredSchemes
            }

            let tokens = trimmedSelection
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var selected: [String] = []
            var invalid: [String] = []

            for token in tokens {
                if let index = Int(token), discoveredSchemes.indices.contains(index - 1) {
                    selected.append(discoveredSchemes[index - 1])
                    continue
                }

                if let nameMatch = discoveredSchemes.first(
                    where: { $0.caseInsensitiveCompare(token) == .orderedSame }
                ) {
                    selected.append(nameMatch)
                    continue
                }

                invalid.append(token)
            }

            if !invalid.isEmpty {
                output("Invalid selections: \(invalid.joined(separator: ", ")). Try again.")
                continue
            }

            let uniqueSelection = uniquePreservingOrder(selected)
            output("Selected schemes: \(uniqueSelection.map(green).joined(separator: ", "))")
            return uniqueSelection
        }
    }

    func performWithSpinner<T>(
        prefix: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        guard supportsInteractiveTerminal() else {
            return try await operation()
        }

        return try await withThrowingTaskGroup(of: Void.self, returning: T.self) { group in
            group.addTask {
                await Self.renderSpinner(prefix: prefix)
            }

            do {
                let value = try await operation()
                group.cancelAll()
                while try await group.next() != nil {}
                Self.writeToStdout("\r\u{1B}[2K")
                return value
            } catch {
                group.cancelAll()
                while try await group.next() != nil {}
                Self.writeToStdout("\r\u{1B}[2K")
                throw error
            }
        }
    }

    private func promptOptionalListValue(_ prompt: String) throws -> [String] {
        let rawValue = try promptOptionalValue(prompt)
        return rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func promptSnapshotTestSchemesWithCursor(from schemes: [String]) throws -> [String] {
        try cursorSchemePrompter(schemes)
    }

    private func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var uniqueValues: [String] = []

        for value in values where seen.insert(value).inserted {
            uniqueValues.append(value)
        }

        return uniqueValues
    }

    private func supportsInteractiveTerminal() -> Bool {
        interactiveTerminalCheck()
    }

    private func ensureCanonicalTerminalModeIfTTY() {
        guard supportsInteractiveTerminal() else { return }

        var term = termios()
        guard tcgetattr(STDIN_FILENO, &term) == 0 else { return }

        term.c_lflag |= tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        term.c_iflag |= tcflag_t(ICRNL | IXON | BRKINT | INPCK | ISTRIP)
        term.c_oflag |= tcflag_t(OPOST)
        term.c_cflag |= tcflag_t(CS8)

        _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &term)
    }

    private static func renderSpinner(prefix: String) async {
        let frames = ["|", "/", "-", "\\"]
        var index = 0

        while !Task.isCancelled {
            writeToStdout("\r\(prefix) \(frames[index])")
            index = (index + 1) % frames.count
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private static func writeToStdout(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func green(_ value: String) -> String {
        guard supportsInteractiveTerminal() else { return value }
        return "\u{001B}[32m\(value)\u{001B}[0m"
    }
}
