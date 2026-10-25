import Foundation

/// Inspects the machine's Xcode and loads the private simulator frameworks with `dlopen`.
/// Only the facts that need no booted simulator are filled in; runtime facts stay `nil`.
struct SimulatorEnvironmentInspector {
    private static let coreSimulatorFallbackPath = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework"

    /// Private classes the playground calls into, which must exist once the frameworks have loaded.
    private static let requiredPrivateClasses = ["SimServiceContext", "SimDevice", "SimDeviceSet", "SimDeviceIOClient"]

    let commandRunner: CommandRunning
    let environment: [String: String]

    init(
        commandRunner: CommandRunning = SubprocessRunner(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.commandRunner = commandRunner
        self.environment = environment
    }

    func inspect(udid: String? = nil) -> SimulatorProbeFacts {
        let developerDirectory = resolveDeveloperDirectory()
        let contents = developerDirectory.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }

        let coreSimulator = coreSimulatorBundle(developerDirectory: developerDirectory)
        let simulatorKit = simulatorKitBundle(developerDirectory: developerDirectory, contents: contents)
        let coreSimulatorLoaded = coreSimulator?.load() ?? false
        // SimulatorKit must be loaded before its classes can be looked up.
        let simulatorKitLoaded = simulatorKit?.load() ?? false

        return SimulatorProbeFacts(
            xcodeVersion: xcodeVersion(contents: contents) ?? "unknown",
            coreSimulatorVersion: coreSimulator?.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            coreSimulatorFound: coreSimulatorLoaded,
            simulatorKitFound: simulatorKitLoaded,
            missingPrivateClasses: Self.requiredPrivateClasses.filter { NSClassFromString($0) == nil },
            xpcSymbolsPresent: Self.xpcSymbolsPresent(),
            simulatorUDID: udid,
            framebufferPortFound: nil,
            surfaceMatchesNativeSize: nil,
            deviceHubFlagActive: udid.flatMap { deviceHubFlagActive(udid: $0) },
            displayCount: nil
        )
    }

    /// Device Hub sets this guest notify state, after which the guest disconnects the legacy HID services.
    /// Only readable while the simulator is booted; `nil` when it cannot be read.
    private func deviceHubFlagActive(udid: String) -> Bool? {
        let output = try? commandRunner.run(
            executable: ExternalTools.xcrun,
            arguments: ["simctl", "spawn", udid, "notifyutil", "-g", "com.apple.coredevice.dtuhidd.active"]
        )
        guard let value = output?.split(separator: " ").last?.trimmingCharacters(in: .whitespacesAndNewlines),
              ["0", "1"].contains(value)
        else { return nil }
        return value == "1"
    }

    func resolveDeveloperDirectory() -> String? {
        if let override = environment["DEVELOPER_DIR"], !override.isEmpty { return override }
        let output = try? commandRunner.run(executable: "/usr/bin/xcode-select", arguments: ["-p"])
        let path = output?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    private func coreSimulatorBundle(developerDirectory: String?) -> Bundle? {
        var candidates = [Self.coreSimulatorFallbackPath]
        if let developerDirectory {
            candidates.append("\(developerDirectory)/Library/PrivateFrameworks/CoreSimulator.framework")
        }
        return candidates.lazy.compactMap { Bundle(path: $0) }.first
    }

    /// Xcode 27 moved SimulatorKit to SharedFrameworks; older versions kept it under Developer.
    private func simulatorKitBundle(developerDirectory: String?, contents: URL?) -> Bundle? {
        var candidates: [String] = []
        if let developerDirectory {
            candidates.append("\(developerDirectory)/Library/PrivateFrameworks/SimulatorKit.framework")
        }
        if let contents {
            candidates.append(contents.appendingPathComponent("SharedFrameworks/SimulatorKit.framework").path)
        }
        return candidates.lazy.compactMap { Bundle(path: $0) }.first
    }

    private func xcodeVersion(contents: URL?) -> String? {
        guard let contents,
              let data = try? Data(contentsOf: contents.appendingPathComponent("version.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleShortVersionString"] as? String
    }

    private static func xpcSymbolsPresent() -> Bool {
        guard let handle = dlopen(nil, RTLD_NOW) else { return false }
        let symbols = ["xpc_endpoint_create_mach_port_4sim", "xpc_connection_enable_sim2host_4sim"]
        return symbols.allSatisfy { name in name.withCString { dlsym(handle, $0) != nil } }
    }
}
