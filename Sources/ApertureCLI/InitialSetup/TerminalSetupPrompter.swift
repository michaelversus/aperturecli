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
            let manualSchemes = try promptRequiredListValue(
                "Provide snapshot test schemes manually (comma-separated, for example: MyAppSnapshots,MyFeatureSnapshots)"
            )
            output("Selected schemes: \(manualSchemes.map(green).joined(separator: ", "))")
            return manualSchemes
        }

        if supportsInteractiveTerminal() {
            output("Use arrow keys to move, space to toggle, and enter to confirm.")
            let selectedSchemes = try promptSnapshotTestSchemesWithCursor(from: discoveredSchemes)
            output("Selected schemes: \(selectedSchemes.map(green).joined(separator: ", "))")
            return selectedSchemes
        }

        output("Discovered schemes:")
        for (index, scheme) in discoveredSchemes.enumerated() {
            output("\(index + 1). \(scheme)")
        }

        while true {
            let rawSelection = try promptRequiredValue(
                "Select snapshot test schemes by number or name (comma-separated, or 'all')"
            )
            let trimmedSelection = rawSelection.trimmingCharacters(in: .whitespacesAndNewlines)

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

                if let nameMatch = discoveredSchemes.first(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
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
            if !uniqueSelection.isEmpty {
                output("Selected schemes: \(uniqueSelection.map(green).joined(separator: ", "))")
                return uniqueSelection
            }

            output("Provide at least one scheme.")
        }
    }

    func performWithSpinner<T>(
        prefix: String,
        operation: @escaping () throws -> T
    ) async throws -> T {
        guard supportsInteractiveTerminal() else {
            return try operation()
        }

        let spinnerTask = Task { @Sendable in
            await Self.renderSpinner(prefix: prefix)
        }
        defer {
            spinnerTask.cancel()
            Self.writeToStdout("\r\u{1B}[2K")
        }

        return try operation()
    }

    private func promptRequiredListValue(_ prompt: String) throws -> [String] {
        while true {
            let rawValue = try promptRequiredValue(prompt)
            let values = rawValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if !values.isEmpty {
                return values
            }

            output("Provide at least one scheme.")
        }
    }

    private func promptSnapshotTestSchemesWithCursor(from schemes: [String]) throws -> [String] {
        while true {
            let selection = try cursorSchemePrompter(schemes)
            if !selection.isEmpty {
                return selection
            }
            output("Select at least one scheme.")
        }
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
        TerminalRawModeState.active = 0
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

private struct CursorMultiSelect {
    let options: [String]

    func run() throws -> [String] {
        let rawMode = try TerminalRawMode()
        try rawMode.enable()
        defer {
            rawMode.disable()
            writeToStdout("\u{1B}[?25h")
            writeToStdout("\n")
        }

        writeToStdout("\u{1B}[?25l")

        var cursor = 0
        let viewportSize = max(5, terminalRows() - 8)
        var topIndex = 0
        var selected = Set<Int>()
        var linesRendered = 0

        while true {
            linesRendered = render(
                cursor: cursor,
                topIndex: topIndex,
                viewportSize: viewportSize,
                selected: selected,
                previousLines: linesRendered
            )

            switch readKey() {
            case .up:
                cursor = (cursor - 1 + options.count) % options.count
                topIndex = updatedTopIndex(cursor: cursor, topIndex: topIndex, viewportSize: viewportSize)
            case .down:
                cursor = (cursor + 1) % options.count
                topIndex = updatedTopIndex(cursor: cursor, topIndex: topIndex, viewportSize: viewportSize)
            case .space:
                if selected.contains(cursor) {
                    selected.remove(cursor)
                } else {
                    selected.insert(cursor)
                }
            case .enter:
                if selected.isEmpty {
                    return [options[cursor]]
                }
                return selected.sorted().map { options[$0] }
            case .unknown:
                continue
            }
        }
    }

    private func render(
        cursor: Int,
        topIndex: Int,
        viewportSize: Int,
        selected: Set<Int>,
        previousLines: Int
    ) -> Int {
        var frame = ""
        if previousLines > 0 {
            for _ in 0..<previousLines {
                frame += "\u{1B}[1A\r\u{1B}[2K"
            }
        }

        let endIndex = min(options.count, topIndex + viewportSize)
        let visibleOptions = Array(options[topIndex..<endIndex])
        let startDisplayIndex = min(topIndex + 1, options.count)
        let endDisplayIndex = min(endIndex, options.count)

        frame += "Select snapshot schemes (\(selected.count) selected):\n"
        for (offset, option) in visibleOptions.enumerated() {
            let index = topIndex + offset
            let pointer = index == cursor ? ">" : " "
            let marker = selected.contains(index) ? "(x)" : "( )"
            frame += "\(pointer) \(marker) \(option)\n"
        }

        if visibleOptions.count < viewportSize {
            for _ in 0..<(viewportSize - visibleOptions.count) {
                frame += "\n"
            }
        }

        frame += "Showing \(startDisplayIndex)-\(endDisplayIndex) of \(options.count)\n"
        frame += "Up/Down: move, Space: toggle, Enter: confirm\n"

        writeToStdout(frame)
        return viewportSize + 3
    }

    private func updatedTopIndex(cursor: Int, topIndex: Int, viewportSize: Int) -> Int {
        if cursor < topIndex {
            return cursor
        }
        if cursor >= topIndex + viewportSize {
            return cursor - viewportSize + 1
        }
        return topIndex
    }

    private func readKey() -> Key {
        var byte: UInt8 = 0
        guard read(STDIN_FILENO, &byte, 1) == 1 else {
            return .unknown
        }

        if byte == 0x1B {
            var sequence = [UInt8](repeating: 0, count: 2)
            guard read(STDIN_FILENO, &sequence[0], 1) == 1, read(STDIN_FILENO, &sequence[1], 1) == 1 else {
                return .unknown
            }
            if sequence[0] == 0x5B && sequence[1] == 0x41 {
                return .up
            }
            if sequence[0] == 0x5B && sequence[1] == 0x42 {
                return .down
            }
            return .unknown
        }

        if byte == 0x20 {
            return .space
        }

        if byte == 0x0A || byte == 0x0D {
            return .enter
        }

        return .unknown
    }

    private func writeToStdout(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func terminalRows() -> Int {
        var windowSize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &windowSize) == 0, windowSize.ws_row > 0 {
            return Int(windowSize.ws_row)
        }
        return 24
    }

    private enum Key {
        case up
        case down
        case space
        case enter
        case unknown
    }
}

private struct TerminalRawMode {
    private let original: termios

    init() throws {
        var term = termios()
        guard tcgetattr(STDIN_FILENO, &term) == 0 else {
            throw CleanExit.message("Unable to read terminal attributes.")
        }
        self.original = term
    }

    func enable() throws {
        var raw = original
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON)
        raw.c_iflag &= ~tcflag_t(ICRNL | IXON)

        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw CleanExit.message("Unable to configure terminal for interactive selection.")
        }

        TerminalRawModeState.original = original
        TerminalRawModeState.active = 1
        installTerminalRestoreSignalHandlers()
    }

    func disable() {
        restoreTerminalIfNeeded()
    }
}

private enum TerminalRawModeState {
    nonisolated(unsafe) static var original = termios()
    nonisolated(unsafe) static var active: Darwin.sig_atomic_t = 0
}

private func restoreTerminalIfNeeded() {
    guard TerminalRawModeState.active == 1 else { return }
    var original = TerminalRawModeState.original
    _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
    TerminalRawModeState.active = 0
}

private func terminalRestoreSignalHandler(_ signal: Int32) {
    restoreTerminalIfNeeded()
    _ = Darwin.signal(signal, SIG_DFL)
    Darwin.raise(signal)
}

private func installTerminalRestoreSignalHandlers() {
    _ = Darwin.signal(SIGINT, terminalRestoreSignalHandler)
    _ = Darwin.signal(SIGTERM, terminalRestoreSignalHandler)
    _ = Darwin.signal(SIGHUP, terminalRestoreSignalHandler)
    _ = Darwin.signal(SIGQUIT, terminalRestoreSignalHandler)
}
