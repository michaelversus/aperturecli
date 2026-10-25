import Foundation

/// Finds the SDK to build against and the iOS version of the simulator the harness will run on.
struct HarnessTargetResolver {
    let commandRunner: CommandRunning
    let udid: String

    func resolve() throws -> HarnessTarget {
        let sdkPath = try commandRunner
            .run(executable: ExternalTools.xcrun, arguments: ["--sdk", "iphonesimulator", "--show-sdk-path"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceList = try commandRunner
            .run(executable: ExternalTools.xcrun, arguments: ["simctl", "list", "devices", "--json"])
        let version = try SimulatorRuntimeVersionParser.iOSVersion(
            ofDevice: udid,
            inDeviceListJSON: Data(deviceList.utf8)
        )
        return HarnessTarget(sdkPath: sdkPath, iOSVersion: version)
    }
}
