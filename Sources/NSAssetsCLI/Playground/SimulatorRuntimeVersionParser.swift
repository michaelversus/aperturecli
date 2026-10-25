import Foundation

/// Reads a device's iOS version out of `simctl list devices --json`.
enum SimulatorRuntimeVersionParser {
    private struct Device: Decodable {
        let udid: String
    }

    private static let iOSRuntimePrefix = "com.apple.CoreSimulator.SimRuntime.iOS-"

    static func iOSVersion(ofDevice udid: String, inDeviceListJSON json: Data) throws -> String {
        let list = try JSONDecoder().decode([String: [String: [Device]]].self, from: json)
        guard let runtime = list["devices"]?.first(where: { entry in
            entry.value.contains { $0.udid.caseInsensitiveCompare(udid) == .orderedSame }
        })?.key else {
            throw PlaygroundError.deviceNotFound(udid)
        }
        guard runtime.hasPrefix(iOSRuntimePrefix) else {
            throw PlaygroundError.unsupportedPlatform(runtime)
        }
        return runtime.dropFirst(iOSRuntimePrefix.count).replacingOccurrences(of: "-", with: ".")
    }
}
