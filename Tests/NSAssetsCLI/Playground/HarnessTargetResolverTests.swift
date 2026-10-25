import Foundation
import Testing
@testable import NSAssetsCLI

struct HarnessTargetResolverTests {
    private let deviceList = """
    {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"UDID-1","name":"iPhone 17e"}]}}
    """

    @Test
    func resolvesTheSDKAndTheDevicesRuntimeVersion() throws {
        let runner = MockCommandRunner(queuedResults: [.success("/sdk/iPhoneSimulator.sdk\n"), .success(deviceList)])
        let resolver = HarnessTargetResolver(commandRunner: runner, udid: "UDID-1")

        let target = try resolver.resolve()

        #expect(target == HarnessTarget(sdkPath: "/sdk/iPhoneSimulator.sdk", iOSVersion: "27.0"))
        #expect(runner.invocations.map(\.arguments) == [
            ["--sdk", "iphonesimulator", "--show-sdk-path"],
            ["simctl", "list", "devices", "--json"]
        ])
    }

    @Test
    func aDeviceThatIsNotListedIsReported() {
        let runner = MockCommandRunner(queuedResults: [.success("/sdk\n"), .success(deviceList)])
        let resolver = HarnessTargetResolver(commandRunner: runner, udid: "OTHER")

        #expect(throws: PlaygroundError.deviceNotFound("OTHER")) { try resolver.resolve() }
    }
}
