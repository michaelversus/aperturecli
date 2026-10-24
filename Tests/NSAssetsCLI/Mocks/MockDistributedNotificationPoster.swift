import Foundation
@testable import NSAssetsCLI

final class MockDistributedNotificationPoster: DistributedNotificationPosting, @unchecked Sendable {
    struct Post {
        let name: Notification.Name
        let userInfo: [AnyHashable: Any]
    }

    private let lock = NSLock()
    private var recorded: [Post] = []

    var posts: [Post] { lock.withLock { recorded } }

    func post(name: Notification.Name, userInfo: [AnyHashable: Any]) {
        lock.withLock { recorded.append(Post(name: name, userInfo: userInfo)) }
    }
}
