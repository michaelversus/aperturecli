import Darwin
import ArgumentParser

protocol TerminalMode {
    func enable() throws
    func disable()
}

struct TerminalRawMode: TerminalMode {
    private let original: termios
    private let terminal: TerminalOperations

    init(terminal: TerminalOperations = .live) throws {
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

        TerminalRawModeState.original = original
        TerminalRawModeState.setAttributes = terminal.setAttributes
        TerminalRawModeState.active = 1
        terminal.installRestoreSignalHandlers()
    }

    func disable() {
        restoreTerminalIfNeeded()
    }
}

struct TerminalOperations: @unchecked Sendable {
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

    static let live = TerminalOperations(
        getAttributes: tcgetattr,
        setAttributes: { fileDescriptor, actions, terminalAttributes in
            tcsetattr(fileDescriptor, actions, terminalAttributes)
        },
        installRestoreSignalHandlers: installTerminalRestoreSignalHandlers
    )
}

enum TerminalRawModeState {
    nonisolated(unsafe) static var original = termios()
    nonisolated(unsafe) static var setAttributes: TerminalOperations.SetAttributes?
    nonisolated(unsafe) static var active: Darwin.sig_atomic_t = 0
}

private func restoreTerminalIfNeeded() {
    guard TerminalRawModeState.active == 1 else { return }
    var original = TerminalRawModeState.original
    let setAttributes = TerminalRawModeState.setAttributes ?? { fileDescriptor, actions, terminalAttributes in
        tcsetattr(fileDescriptor, actions, terminalAttributes)
    }
    _ = setAttributes(STDIN_FILENO, TCSAFLUSH, &original)
    TerminalRawModeState.setAttributes = nil
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
