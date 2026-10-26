import Foundation
@testable import NSAssetsCLI

final class MockDistributedNotificationObserver: DistributedNotificationObserving, @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [Int: (name: Notification.Name, handler: @Sendable () -> Void)] = [:]
    private var nextID = 0

    var activeNames: [Notification.Name] { lock.withLock { handlers.values.map(\.name) } }

    func observe(name: Notification.Name, handler: @escaping @Sendable () -> Void) -> @Sendable () -> Void {
        let id = lock.withLock {
            nextID += 1
            handlers[nextID] = (name, handler)
            return nextID
        }
        return { [self] in lock.withLock { _ = handlers.removeValue(forKey: id) } }
    }

    func fire(_ name: Notification.Name) {
        let matching = lock.withLock { handlers.values.filter { $0.name == name }.map(\.handler) }
        matching.forEach { $0() }
    }
}
