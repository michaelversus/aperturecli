import Foundation
import Testing
@testable import NSAssetsCLI

struct SimctlHarnessControllerTests {
    @Test(arguments: [(PlaygroundTheme.dark, "dark"), (PlaygroundTheme.light, "light")])
    func appearanceIsSetBeforeTheHarnessLaunches(theme: PlaygroundTheme, word: String) throws {
        let runner = MockCommandRunner(queuedResults: [.success("")])
        let controller = SimctlHarnessController(udid: "UDID-1", commandRunner: runner)

        try controller.setAppearance(theme)

        #expect(runner.invocations.map(\.arguments) == [["simctl", "ui", "UDID-1", "appearance", word]])
    }

    @Test
    func installsTheBundleOnTheSimulator() throws {
        let runner = MockCommandRunner(queuedResults: [.success("")])
        let controller = SimctlHarnessController(udid: "UDID-1", commandRunner: runner)

        try controller.install(appPath: "/cache/h1/Harness.app")

        #expect(runner.invocations.map(\.arguments) == [["simctl", "install", "UDID-1", "/cache/h1/Harness.app"]])
    }

    @Test
    func relaunchTerminatesTheRunningHarnessAndLaunchesTheNewOne() throws {
        let runner = MockCommandRunner(queuedResults: [.success(""), .success("")])
        let controller = SimctlHarnessController(udid: "UDID-1", commandRunner: runner)

        try controller.relaunch()

        let bundle = HarnessSourceGenerator.bundleIdentifier
        #expect(runner.invocations.map(\.arguments) == [
            ["simctl", "terminate", "UDID-1", bundle],
            ["simctl", "launch", "UDID-1", bundle]
        ])
    }

    @Test
    func clearTerminatesTheHarness() throws {
        let runner = MockCommandRunner(queuedResults: [.success("")])
        let controller = SimctlHarnessController(udid: "UDID-1", commandRunner: runner)

        try controller.clear()

        #expect(runner.invocations.map(\.arguments) == [
            ["simctl", "terminate", "UDID-1", HarnessSourceGenerator.bundleIdentifier]
        ])
    }

    @Test
    func clearingWhenNothingIsLoadedSucceeds() throws {
        let nothing = SubprocessRunnerError.commandFailed(
            executable: ExternalTools.xcrun,
            arguments: [],
            exitCode: 3,
            output: "Simulator device failed to terminate. found nothing to terminate"
        )
        let runner = MockCommandRunner(queuedResults: [.failure(nothing)])
        let controller = SimctlHarnessController(udid: "UDID-1", commandRunner: runner)

        try controller.clear()
    }

    @Test
    func clearFailsForAnyOtherTerminateFailure() {
        let broken = SubprocessRunnerError.commandFailed(
            executable: ExternalTools.xcrun,
            arguments: [],
            exitCode: 164,
            output: "Unable to lookup in current state: Shutdown"
        )
        let runner = MockCommandRunner(queuedResults: [.failure(broken)])
        let controller = SimctlHarnessController(udid: "UDID-1", commandRunner: runner)

        #expect(throws: SubprocessRunnerError.self) { try controller.clear() }
    }

    @Test
    func relaunchStillLaunchesWhenNothingWasRunning() throws {
        struct NotRunning: Error {}
        let runner = MockCommandRunner(queuedResults: [.failure(NotRunning()), .success("")])
        let controller = SimctlHarnessController(udid: "UDID-1", commandRunner: runner)

        try controller.relaunch()

        #expect(runner.invocations.count == 2)
    }
}
