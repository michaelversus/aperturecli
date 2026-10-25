import Foundation

/// Finds the simulator `.nsassets.json` asks for, among the simulators that are already booted.
///
/// It never boots a simulator and never guesses between several: a simulator the user did not mean is never touched.
struct ConfiguredSimulatorResolver {
    private struct Device: Decodable {
        let udid: String
        let name: String
        let state: String
    }

    private static let iOSRuntimePrefix = "com.apple.CoreSimulator.SimRuntime.iOS-"

    let configLoader: any NSAssetsConfigLoading
    let commandRunner: CommandRunning
    let workingDirectory: String

    func resolve() throws -> String {
        let config = try configLoader.load(atRootPath: workingDirectory)
        let runtime = Self.iOSRuntimePrefix + config.iosVersion.replacingOccurrences(of: ".", with: "-")
        let json = try commandRunner.run(
            executable: ExternalTools.xcrun,
            arguments: ["simctl", "list", "devices", "available", "--json"]
        )
        let list = try JSONDecoder().decode([String: [String: [Device]]].self, from: Data(json.utf8))
        let matches = (list["devices"]?[runtime] ?? [])
            .filter { $0.state == "Booted" && $0.name.caseInsensitiveCompare(config.simulatorModel) == .orderedSame }
            .map(\.udid)
            .sorted()
        switch matches.count {
        case 1:
            return matches[0]
        case 0:
            throw PlaygroundError.noMatchingSimulator(model: config.simulatorModel, iosVersion: config.iosVersion)
        default:
            throw PlaygroundError.ambiguousSimulators(
                model: config.simulatorModel, iosVersion: config.iosVersion, udids: matches
            )
        }
    }
}
