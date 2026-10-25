import Foundation
@testable import NSAssetsCLI

/// Collects the statuses a presenter reports so a test can assert on their order.
final class StatusRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [PlaygroundComponentStatus] = []

    var statuses: [PlaygroundComponentStatus] { lock.withLock { recorded } }

    func record(_ status: PlaygroundComponentStatus) {
        lock.withLock { recorded.append(status) }
    }
}
