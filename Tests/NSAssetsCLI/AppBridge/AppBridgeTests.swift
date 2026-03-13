import Foundation
import Testing
@testable import NSAssetsCLI

struct AppBridgeTests {
    @Test
    func postsWhenAppAlreadyRunning() {
        let checker = SequenceAppRunningChecker(responses: [true])
        let launcher = MockAppLauncher()
        let prompter = MockUserPrompter(canPrompt: true, response: true)
        let poster = MockNotificationPoster()
        var outputLines: [String] = []

        let bridge = AppBridge(
            appRunningChecker: checker,
            appLauncher: launcher,
            userPrompter: prompter,
            notificationPoster: poster,
            output: { outputLines.append($0) },
            launchTimeout: 0.1,
            pollInterval: 0,
            sleep: { _ in }
        )

        bridge.notifyAppIfNeeded(payload: samplePayload)

        #expect(launcher.bundleIDs.isEmpty)
        #expect(prompter.promptCallCount == 0)
        #expect(poster.invocations.count == 1)
        #expect(outputLines.isEmpty)
        #expect((poster.invocations[0].userInfo["artifactPath"] as? String) == samplePayload.artifactPath)
    }

    @Test
    func promptsAndLaunchesInInteractiveModeWhenUserAccepts() {
        let checker = SequenceAppRunningChecker(responses: [false, true])
        let launcher = MockAppLauncher()
        let prompter = MockUserPrompter(canPrompt: true, response: true)
        let poster = MockNotificationPoster()

        let bridge = AppBridge(
            appRunningChecker: checker,
            appLauncher: launcher,
            userPrompter: prompter,
            notificationPoster: poster,
            output: { _ in },
            launchTimeout: 0.1,
            pollInterval: 0,
            sleep: { _ in }
        )

        bridge.notifyAppIfNeeded(payload: samplePayload)

        #expect(prompter.promptCallCount == 1)
        #expect(launcher.bundleIDs == [AppBridgeConstants.bundleID])
        #expect(poster.invocations.count == 1)
    }

    @Test
    func doesNothingInInteractiveModeWhenUserDeclines() {
        let checker = SequenceAppRunningChecker(responses: [false])
        let launcher = MockAppLauncher()
        let prompter = MockUserPrompter(canPrompt: true, response: false)
        let poster = MockNotificationPoster()
        var outputLines: [String] = []

        let bridge = AppBridge(
            appRunningChecker: checker,
            appLauncher: launcher,
            userPrompter: prompter,
            notificationPoster: poster,
            output: { outputLines.append($0) },
            launchTimeout: 0.1,
            pollInterval: 0,
            sleep: { _ in }
        )

        bridge.notifyAppIfNeeded(payload: samplePayload)

        #expect(prompter.promptCallCount == 1)
        #expect(launcher.bundleIDs.isEmpty)
        #expect(poster.invocations.isEmpty)
        #expect(outputLines.contains("NSAssets Studio is not running. Skipping notification."))
    }

    @Test
    func autoLaunchesInNonInteractiveMode() {
        let checker = SequenceAppRunningChecker(responses: [false, true])
        let launcher = MockAppLauncher()
        let prompter = MockUserPrompter(canPrompt: false, response: false)
        let poster = MockNotificationPoster()

        let bridge = AppBridge(
            appRunningChecker: checker,
            appLauncher: launcher,
            userPrompter: prompter,
            notificationPoster: poster,
            output: { _ in },
            launchTimeout: 0.1,
            pollInterval: 0,
            sleep: { _ in }
        )

        bridge.notifyAppIfNeeded(payload: samplePayload)

        #expect(prompter.promptCallCount == 0)
        #expect(launcher.bundleIDs == [AppBridgeConstants.bundleID])
        #expect(poster.invocations.count == 1)
    }

    @Test
    func launchFailureSkipsNotificationAndEmitsDiagnostic() {
        let checker = SequenceAppRunningChecker(responses: [false])
        let launcher = MockAppLauncher(error: NSError(domain: "launch", code: 1))
        let prompter = MockUserPrompter(canPrompt: false, response: false)
        let poster = MockNotificationPoster()
        var outputLines: [String] = []

        let bridge = AppBridge(
            appRunningChecker: checker,
            appLauncher: launcher,
            userPrompter: prompter,
            notificationPoster: poster,
            output: { outputLines.append($0) },
            launchTimeout: 0.1,
            pollInterval: 0,
            sleep: { _ in }
        )

        bridge.notifyAppIfNeeded(payload: samplePayload)

        #expect(poster.invocations.isEmpty)
        #expect(outputLines.contains { $0.contains("Failed to open NSAssets Studio") })
    }

    @Test
    func timeoutSkipsNotificationAndEmitsDiagnostic() {
        let checker = SequenceAppRunningChecker(responses: [false, false, false, false, false])
        let launcher = MockAppLauncher()
        let prompter = MockUserPrompter(canPrompt: false, response: false)
        let poster = MockNotificationPoster()
        var outputLines: [String] = []

        let bridge = AppBridge(
            appRunningChecker: checker,
            appLauncher: launcher,
            userPrompter: prompter,
            notificationPoster: poster,
            output: { outputLines.append($0) },
            launchTimeout: 0,
            pollInterval: 0,
            sleep: { _ in }
        )

        bridge.notifyAppIfNeeded(payload: samplePayload)

        #expect(poster.invocations.isEmpty)
        #expect(outputLines.contains { $0.contains("did not become active within") })
    }
}

private let samplePayload = AppNotificationPayload(
    schemeName: "Snapshots",
    projectName: "MyApp",
    artifactPath: "/repo/nsassets-artifacts/xcresults/Snapshots.json",
    xcresultPath: "/tmp/Snapshots.xcresult"
)

private final class SequenceAppRunningChecker: AppRunningChecking {
    private let responses: [Bool]
    private var index: Int = 0

    init(responses: [Bool]) {
        self.responses = responses
    }

    func isAppRunning(bundleID: String) -> Bool {
        _ = bundleID
        if index < responses.count {
            defer { index += 1 }
            return responses[index]
        }
        return responses.last ?? false
    }
}

private final class MockAppLauncher: AppLaunching {
    private(set) var bundleIDs: [String] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func launchApp(bundleID: String) throws {
        bundleIDs.append(bundleID)
        if let error {
            throw error
        }
    }
}

private final class MockUserPrompter: UserConfirmationPrompting {
    private(set) var promptCallCount: Int = 0
    private let shouldPrompt: Bool
    private let response: Bool

    init(canPrompt: Bool, response: Bool) {
        self.shouldPrompt = canPrompt
        self.response = response
    }

    func canPromptUser() -> Bool {
        shouldPrompt
    }

    func promptToOpenApp(appName: String, defaultValue: Bool) throws -> Bool {
        _ = appName
        _ = defaultValue
        promptCallCount += 1
        return response
    }
}

private final class MockNotificationPoster: DistributedNotificationPosting {
    struct Invocation {
        let name: Notification.Name
        let userInfo: [AnyHashable: Any]
    }

    private(set) var invocations: [Invocation] = []

    func post(name: Notification.Name, userInfo: [AnyHashable: Any]) {
        invocations.append(Invocation(name: name, userInfo: userInfo))
    }
}
