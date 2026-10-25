import Testing
@testable import NSAssetsCLI

struct SimulatorHardwareButtonTests {
    @Test(arguments: [
        (SimulatorHardwareButton.lock, UInt64(0x30)),
        (.volumeUp, 0xE9),
        (.volumeDown, 0xEA)
    ])
    func aPhysicalButtonIsAConsumerPageUsage(button: SimulatorHardwareButton, usage: UInt64) {
        #expect(button.consumerUsage == usage)
    }

    @Test
    func homeIsAGestureNotAButton() {
        #expect(SimulatorHardwareButton.home.consumerUsage == nil)
    }
}
