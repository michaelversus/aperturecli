import Foundation

struct AppBridge: AppBridgeHandling {
    let appRunningChecker: AppRunningChecking
    let appLauncher: AppLaunching
    let userPrompter: UserConfirmationPrompting
    let notificationPoster: DistributedNotificationPosting
    let output: (String) -> Void
    let launchTimeout: TimeInterval
    let pollInterval: TimeInterval
    let sleep: (TimeInterval) -> Void

    init(
        appRunningChecker: AppRunningChecking,
        appLauncher: AppLaunching,
        userPrompter: UserConfirmationPrompting,
        notificationPoster: DistributedNotificationPosting,
        output: @escaping (String) -> Void,
        launchTimeout: TimeInterval = 5,
        pollInterval: TimeInterval = 0.1,
        sleep: @escaping (TimeInterval) -> Void = { interval in
            Thread.sleep(forTimeInterval: interval)
        }
    ) {
        self.appRunningChecker = appRunningChecker
        self.appLauncher = appLauncher
        self.userPrompter = userPrompter
        self.notificationPoster = notificationPoster
        self.output = output
        self.launchTimeout = launchTimeout
        self.pollInterval = pollInterval
        self.sleep = sleep
    }

    func notifyAppIfNeeded(payload: AppNotificationPayload) {
        if appRunningChecker.isAppRunning(bundleID: AppBridgeConstants.bundleID) {
            postNotification(payload: payload)
            return
        }

        let shouldOpenApp = shouldOpenAppIfNotRunning()
        guard shouldOpenApp else {
            output("\(AppBridgeConstants.appDisplayName) is not running. Skipping notification.")
            return
        }

        do {
            try appLauncher.launchApp(bundleID: AppBridgeConstants.bundleID)
        } catch {
            output(
                "Failed to open \(AppBridgeConstants.appDisplayName): \(error.localizedDescription). "
                    + "Artifact parsing completed; app notification skipped."
            )
            return
        }

        guard waitUntilRunning(timeout: launchTimeout) else {
            output(
                "\(AppBridgeConstants.appDisplayName) did not become active within "
                    + "\(launchTimeout)s. Artifact parsing completed; app notification skipped."
            )
            return
        }

        postNotification(payload: payload)
    }

    private func shouldOpenAppIfNotRunning() -> Bool {
        if userPrompter.canPromptUser() {
            do {
                return try userPrompter.promptToOpenApp(
                    appName: AppBridgeConstants.appDisplayName,
                    defaultValue: false
                )
            } catch {
                output("Failed to read confirmation input: \(error.localizedDescription).")
                return false
            }
        }

        output(
            "\(AppBridgeConstants.appDisplayName) is not running. "
                + "Launching automatically in non-interactive mode."
        )
        return true
    }

    private func waitUntilRunning(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if appRunningChecker.isAppRunning(bundleID: AppBridgeConstants.bundleID) {
                return true
            }
            sleep(pollInterval)
        }
        return appRunningChecker.isAppRunning(bundleID: AppBridgeConstants.bundleID)
    }

    private func postNotification(payload: AppNotificationPayload) {
        notificationPoster.post(
            name: AppBridgeConstants.notificationName,
            userInfo: payload.userInfo
        )
    }
}

struct NoopAppBridge: AppBridgeHandling {
    func notifyAppIfNeeded(payload: AppNotificationPayload) {
        _ = payload
    }
}
