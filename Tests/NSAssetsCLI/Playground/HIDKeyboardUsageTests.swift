import Testing
@testable import NSAssetsCLI

struct HIDKeyboardUsageTests {
    @Test(arguments: [
        ("KeyA", 0x04), ("KeyZ", 0x1D), ("Digit1", 0x1E), ("Digit0", 0x27), ("Enter", 0x28), ("Escape", 0x29),
        ("Backspace", 0x2A), ("Tab", 0x2B), ("Space", 0x2C), ("Slash", 0x38), ("ArrowRight", 0x4F),
        ("ArrowUp", 0x52), ("ShiftLeft", 0xE1), ("MetaLeft", 0xE3)
    ])
    func aDOMCodeMapsToItsUSBUsage(code: String, usage: Int) {
        #expect(HIDKeyboardUsage.usage(forDOMCode: code) == UInt64(usage))
    }

    @Test(arguments: ["", "F24", "keya", "MediaPlayPause"])
    func anUnknownCodeHasNoUsage(code: String) {
        #expect(HIDKeyboardUsage.usage(forDOMCode: code) == nil)
    }
}
