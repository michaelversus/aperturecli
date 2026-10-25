import Foundation
import Testing
@testable import NSAssetsCLI

struct ConfiguredSimulatorResolverTests {
    private func device(_ udid: String, _ name: String, _ state: String) -> String {
        #"{"udid":"\#(udid)","name":"\#(name)","state":"\#(state)","isAvailable":true}"#
    }

    private func config(model: String = "iPhone 16 Pro", ios: String = "18.2") -> NSAssetsConfig {
        NSAssetsConfig(
            repoRoot: "/repo", iosVersion: ios, simulatorModel: model, xcodeVersion: "16",
            projectFileName: "A.xcodeproj", spmPackagesContainerPath: "Packages", snapshotTestSchemes: []
        )
    }

    private func list(_ runtimes: [String: [String]]) -> String {
        let entries = runtimes.map { runtime, devices in
            #""com.apple.CoreSimulator.SimRuntime.\#(runtime)":[\#(devices.joined(separator: ","))]"#
        }
        return #"{"devices":{\#(entries.joined(separator: ","))}}"#
    }

    private func resolver(devices: String) -> ConfiguredSimulatorResolver {
        ConfiguredSimulatorResolver(
            configLoader: MockNSAssetsConfigLoader(config: config()),
            commandRunner: MockCommandRunner(queuedResults: [.success(devices)]),
            workingDirectory: "/repo"
        )
    }

    @Test
    func picksTheOnlyBootedDeviceWithTheConfiguredModelAndVersion() throws {
        let devices = list([
            "iOS-18-2": [device("A", "iPhone 16 Pro", "Booted"), device("B", "iPhone 16", "Booted")],
            "iOS-17-5": [device("C", "iPhone 16 Pro", "Booted")]
        ])

        #expect(try resolver(devices: devices).resolve() == "A")
    }

    @Test
    func aShutDownMatchIsNeverUsedOrBooted() {
        let devices = list(["iOS-18-2": [device("A", "iPhone 16 Pro", "Shutdown")]])

        #expect(throws: PlaygroundError.noMatchingSimulator(model: "iPhone 16 Pro", iosVersion: "18.2")) {
            try resolver(devices: devices).resolve()
        }
    }

    @Test
    func severalBootedMatchesAreRefusedWithTheirUDIDs() {
        let devices = list([
            "iOS-18-2": [device("B", "iPhone 16 Pro", "Booted"), device("A", "iPhone 16 Pro", "Booted")]
        ])

        #expect(
            throws: PlaygroundError.ambiguousSimulators(model: "iPhone 16 Pro", iosVersion: "18.2", udids: ["A", "B"])
        ) { try resolver(devices: devices).resolve() }
    }

    @Test
    func itReadsTheConfigFromTheWorkingDirectoryAndListsAvailableDevices() throws {
        let devices = list(["iOS-18-2": [device("A", "iPhone 16 Pro", "Booted")]])
        let runner = MockCommandRunner(queuedResults: [.success(devices)])
        let loader = MockNSAssetsConfigLoader(config: config())

        _ = try ConfiguredSimulatorResolver(
            configLoader: loader, commandRunner: runner, workingDirectory: "/work"
        ).resolve()

        #expect(loader.receivedRootPath == "/work")
        #expect(runner.invocations.first?.arguments == ["simctl", "list", "devices", "available", "--json"])
    }
}
