import Foundation
import Darwin

struct TerminalUserConfirmationPrompter: UserConfirmationPrompting {
    let output: (String) -> Void
    let interactiveTerminalCheck: () -> Bool
    let readInput: () -> String?
    let promptWriter: (String) -> Void

    init(
        output: @escaping (String) -> Void,
        interactiveTerminalCheck: @escaping () -> Bool = {
            isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
        },
        readInput: @escaping () -> String? = { readLine() },
        promptWriter: @escaping (String) -> Void = Self.writeToStdout
    ) {
        self.output = output
        self.interactiveTerminalCheck = interactiveTerminalCheck
        self.readInput = readInput
        self.promptWriter = promptWriter
    }

    func canPromptUser() -> Bool {
        interactiveTerminalCheck()
    }

    func promptToOpenApp(appName: String, defaultValue: Bool) throws -> Bool {
        let promptSuffix = defaultValue ? "[Y/n]" : "[y/N]"

        while true {
            promptWriter("Open \(appName) now? \(promptSuffix): ")
            guard let rawInput = readInput() else {
                throw CocoaError(.userCancelled)
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

    private static func writeToStdout(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
}
