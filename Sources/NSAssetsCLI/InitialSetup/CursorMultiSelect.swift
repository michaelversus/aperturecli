import Foundation
import Darwin

struct CursorMultiSelect {
    let options: [String]

    func run(environment: Environment = .live()) throws -> [String] {
        let rawMode = try environment.makeRawMode()
        try rawMode.enable()
        defer {
            rawMode.disable()
            environment.writeToStdout("\u{1B}[?25h")
            environment.writeToStdout("\n")
        }

        environment.writeToStdout("\u{1B}[?25l")

        var cursor = 0
        let viewportSize = max(5, environment.terminalRows() - 8)
        var topIndex = 0
        var selected = Set<Int>()
        var linesRendered = 0

        while true {
            linesRendered = render(
                cursor: cursor,
                topIndex: topIndex,
                viewportSize: viewportSize,
                selected: selected,
                previousLines: linesRendered,
                writeToStdout: environment.writeToStdout
            )

            switch environment.readKey() {
            case .arrowUp:
                cursor = (cursor - 1 + options.count) % options.count
                topIndex = updatedTopIndex(cursor: cursor, topIndex: topIndex, viewportSize: viewportSize)
            case .arrowDown:
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

    @discardableResult
    func render(
        cursor: Int,
        topIndex: Int,
        viewportSize: Int,
        selected: Set<Int>,
        previousLines: Int,
        writeToStdout: (String) -> Void = Self.writeToStdout
    ) -> Int {
        let frame = makeFrame(
            cursor: cursor,
            topIndex: topIndex,
            viewportSize: viewportSize,
            selected: selected,
            previousLines: previousLines
        )
        writeToStdout(frame)
        return viewportSize + 3
    }

    func makeFrame(
        cursor: Int,
        topIndex: Int,
        viewportSize: Int,
        selected: Set<Int>,
        previousLines: Int
    ) -> String {
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
        return frame
    }

    func updatedTopIndex(cursor: Int, topIndex: Int, viewportSize: Int) -> Int {
        if cursor < topIndex {
            return cursor
        }
        if cursor >= topIndex + viewportSize {
            return cursor - viewportSize + 1
        }
        return topIndex
    }

    static func readKey() -> Key {
        var byte: UInt8 = 0
        guard read(STDIN_FILENO, &byte, 1) == 1 else {
            return .unknown
        }

        // Arrow keys arrive as ANSI escape sequences: ESC [`A`/`B`].
        if byte == 0x1B {
            var sequence = [UInt8](repeating: 0, count: 2)
            guard read(STDIN_FILENO, &sequence[0], 1) == 1, read(STDIN_FILENO, &sequence[1], 1) == 1 else {
                return .unknown
            }
            // ESC [ A
            if sequence[0] == 0x5B && sequence[1] == 0x41 {
                return .arrowUp
            }
            // ESC [ B
            if sequence[0] == 0x5B && sequence[1] == 0x42 {
                return .arrowDown
            }
            return .unknown
        }

        // Space toggles the currently highlighted option.
        if byte == 0x20 {
            return .space
        }

        // Terminals may send either LF or CR for Enter.
        if byte == 0x0A || byte == 0x0D {
            return .enter
        }

        return .unknown
    }

    static func writeToStdout(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    static func terminalRows() -> Int {
        var windowSize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &windowSize) == 0, windowSize.ws_row > 0 {
            return Int(windowSize.ws_row)
        }
        return 24
    }

    struct Environment {
        let makeRawMode: () throws -> any TerminalMode
        let readKey: () -> Key
        let writeToStdout: (String) -> Void
        let terminalRows: () -> Int

        static func live() -> Environment {
            Environment(
                makeRawMode: { try TerminalRawMode() },
                readKey: CursorMultiSelect.readKey,
                writeToStdout: CursorMultiSelect.writeToStdout,
                terminalRows: CursorMultiSelect.terminalRows
            )
        }
    }

    enum Key {
        case arrowUp
        case arrowDown
        case space
        case enter
        case unknown
    }
}
