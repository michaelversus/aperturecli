import Darwin
import ArgumentParser

protocol TerminalMode {
    func enable() throws
    func disable()
}

final class TerminalRawMode: TerminalMode {
    private let original: termios
    private let terminal: TerminalOperations
    private var isEnabled = false

    init(terminal: TerminalOperations = .live()) throws {
        self.terminal = terminal
        var term = termios()
        guard terminal.getAttributes(STDIN_FILENO, &term) == 0 else {
            throw CleanExit.message("Unable to read terminal attributes.")
        }
        self.original = term
    }

    func enable() throws {
        var raw = original
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON)
        raw.c_iflag &= ~tcflag_t(ICRNL | IXON)

        guard terminal.setAttributes(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw CleanExit.message("Unable to configure terminal for interactive selection.")
        }

        isEnabled = true
        terminal.installRestoreSignalHandlers()
    }

    func disable() {
        guard isEnabled else { return }
        var restored = original
        _ = terminal.setAttributes(STDIN_FILENO, TCSAFLUSH, &restored)
        isEnabled = false
    }
}

struct TerminalOperations {
    typealias GetAttributes = (
        _ fileDescriptor: Int32,
        _ terminalAttributes: UnsafeMutablePointer<termios>
    ) -> Int32
    typealias SetAttributes = (
        _ fileDescriptor: Int32,
        _ actions: Int32,
        _ terminalAttributes: UnsafeMutablePointer<termios>
    ) -> Int32

    let getAttributes: GetAttributes
    let setAttributes: SetAttributes
    let installRestoreSignalHandlers: () -> Void

    static func live() -> TerminalOperations {
        TerminalOperations(
            getAttributes: tcgetattr,
            setAttributes: { fileDescriptor, actions, terminalAttributes in
                tcsetattr(fileDescriptor, actions, terminalAttributes)
            },
            installRestoreSignalHandlers: installTerminalRestoreSignalHandlers
        )
    }
}

private func terminalRestoreSignalHandler(_ signal: Int32) {
    restoreTerminalToCanonicalMode()
    _ = Darwin.signal(signal, SIG_DFL)
    Darwin.raise(signal)
}

private func installTerminalRestoreSignalHandlers() {
    _ = Darwin.signal(SIGINT, terminalRestoreSignalHandler)
    _ = Darwin.signal(SIGTERM, terminalRestoreSignalHandler)
    _ = Darwin.signal(SIGHUP, terminalRestoreSignalHandler)
    _ = Darwin.signal(SIGQUIT, terminalRestoreSignalHandler)
}

private func restoreTerminalToCanonicalMode() {
    var term = termios()
    guard tcgetattr(STDIN_FILENO, &term) == 0 else { return }

    term.c_lflag |= tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
    term.c_iflag |= tcflag_t(ICRNL | IXON | BRKINT | INPCK | ISTRIP)
    term.c_oflag |= tcflag_t(OPOST)
    term.c_cflag |= tcflag_t(CS8)

    _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &term)
}
