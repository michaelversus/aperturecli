import Foundation
import Testing
@testable import NSAssetsCLI

struct SimulatorRuntimeVersionParserTests {
    private let json = """
    {"devices":{
      "com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"udid":"AAA","name":"iPhone 16"}],
      "com.apple.CoreSimulator.SimRuntime.iOS-26-4":[{"udid":"BBB","name":"iPhone 17"},{"udid":"CCC","name":"iPad"}],
      "com.apple.CoreSimulator.SimRuntime.watchOS-11-0":[{"udid":"DDD","name":"Watch"}]
    }}
    """

    @Test
    func findsTheRuntimeVersionOfADevice() throws {
        let version = try SimulatorRuntimeVersionParser.iOSVersion(ofDevice: "CCC", inDeviceListJSON: Data(json.utf8))

        #expect(version == "26.4")
    }

    @Test
    func aDeviceFromAnotherPlatformIsRejected() {
        #expect(throws: PlaygroundError.self) {
            try SimulatorRuntimeVersionParser.iOSVersion(ofDevice: "DDD", inDeviceListJSON: Data(json.utf8))
        }
    }

    @Test
    func anUnknownDeviceIsRejected() {
        #expect(throws: PlaygroundError.self) {
            try SimulatorRuntimeVersionParser.iOSVersion(ofDevice: "ZZZ", inDeviceListJSON: Data(json.utf8))
        }
    }

    @Test
    func theUDIDMatchIsCaseInsensitive() throws {
        let version = try SimulatorRuntimeVersionParser.iOSVersion(ofDevice: "aaa", inDeviceListJSON: Data(json.utf8))

        #expect(version == "18.0")
    }
}
