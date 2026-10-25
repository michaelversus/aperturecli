/// Maps the DOM `KeyboardEvent.code` of a physical key to its USB HID keyboard usage (usage page 0x07).
enum HIDKeyboardUsage {
    private static let usages: [String: UInt64] = {
        var table: [String: UInt64] = [
            "Digit0": 0x27, "Enter": 0x28, "Escape": 0x29, "Backspace": 0x2A, "Tab": 0x2B, "Space": 0x2C,
            "Minus": 0x2D, "Equal": 0x2E, "BracketLeft": 0x2F, "BracketRight": 0x30, "Backslash": 0x31,
            "Semicolon": 0x33, "Quote": 0x34, "Backquote": 0x35, "Comma": 0x36, "Period": 0x37, "Slash": 0x38,
            "Delete": 0x4C, "ArrowRight": 0x4F, "ArrowLeft": 0x50, "ArrowDown": 0x51, "ArrowUp": 0x52,
            "ControlLeft": 0xE0, "ShiftLeft": 0xE1, "AltLeft": 0xE2, "MetaLeft": 0xE3,
            "ControlRight": 0xE4, "ShiftRight": 0xE5, "AltRight": 0xE6, "MetaRight": 0xE7
        ]
        for (offset, letter) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() {
            table["Key\(letter)"] = 0x04 + UInt64(offset)
        }
        for digit in 1...9 {
            table["Digit\(digit)"] = 0x1E + UInt64(digit - 1)
        }
        return table
    }()

    static func usage(forDOMCode code: String) -> UInt64? {
        usages[code]
    }
}
