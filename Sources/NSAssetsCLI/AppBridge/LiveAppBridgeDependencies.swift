import AppKit
import Foundation

struct RunningApplicationChecker: AppRunningChecking {
    func isAppRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

struct OpenCommandAppLauncher: AppLaunching {
    let commandRunner: CommandRunning

    func launchApp(bundleID: String) throws {
        _ = try commandRunner.run(executable: "/usr/bin/open", arguments: ["-b", bundleID])
    }
}

struct DistributedNotificationPoster: DistributedNotificationPosting {
    func post(name: Notification.Name, userInfo: [AnyHashable: Any]) {
        DistributedNotificationCenter.default().postNotificationName(
            name,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }
}
