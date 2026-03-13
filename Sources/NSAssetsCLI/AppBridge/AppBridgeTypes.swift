import Foundation

struct AppNotificationPayload: Sendable {
    let schemeName: String
    let projectName: String
    let artifactPath: String
    let xcresultPath: String

    var userInfo: [AnyHashable: Any] {
        [
            "schemeName": schemeName,
            "projectName": projectName,
            "artifactPath": artifactPath,
            "xcresultPath": xcresultPath
        ]
    }
}

enum AppBridgeConstants {
    static let bundleID = "app.nsbuilder.nsassets"
    static let notificationName = Notification.Name("app.nsbuilder.nsassets.xcresult.updated")
    static let appDisplayName = "NSAssets Studio"
}

protocol AppBridgeHandling {
    func notifyAppIfNeeded(payload: AppNotificationPayload)
}

protocol AppRunningChecking {
    func isAppRunning(bundleID: String) -> Bool
}

protocol AppLaunching {
    func launchApp(bundleID: String) throws
}

protocol UserConfirmationPrompting {
    func canPromptUser() -> Bool
    func promptToOpenApp(appName: String, defaultValue: Bool) throws -> Bool
}

protocol DistributedNotificationPosting {
    func post(name: Notification.Name, userInfo: [AnyHashable: Any])
}
