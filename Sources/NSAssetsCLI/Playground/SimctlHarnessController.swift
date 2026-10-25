/// Drives one simulator's harness app with `simctl`. Marked `@unchecked Sendable` for the same reason as
/// `HarnessBuilder`: one component is presented at a time.
struct SimctlHarnessController: HarnessSimulatorControlling, @unchecked Sendable {
    let udid: String
    let commandRunner: CommandRunning

    func setAppearance(_ theme: PlaygroundTheme) throws {
        try simctl(["ui", udid, "appearance", theme.rawValue])
    }

    func install(appPath: String) throws {
        try simctl(["install", udid, appPath])
    }

    func relaunch() throws {
        // Terminating fails when the harness is not running, which is fine.
        try? simctl(["terminate", udid, HarnessSourceGenerator.bundleIdentifier])
        try simctl(["launch", udid, HarnessSourceGenerator.bundleIdentifier])
    }

    private func simctl(_ arguments: [String]) throws {
        _ = try commandRunner.run(executable: "/usr/bin/xcrun", arguments: ["simctl"] + arguments)
    }
}
