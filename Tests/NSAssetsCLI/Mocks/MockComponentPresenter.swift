import Foundation
@testable import NSAssetsCLI

/// Reports the statuses it was given, one at a time, and tracks whether presentations ever overlapped.
final class MockComponentPresenter: PlaygroundComponentPresenting, @unchecked Sendable {
    private let lock = NSLock()
    private var presented: [PlaygroundComponentRequest] = []
    private var running = 0
    private var overlapped = false
    private let statuses: [PlaygroundComponentStatus.State]
    private let duration: Duration

    init(statuses: [PlaygroundComponentStatus.State] = [.building, .ready], duration: Duration = .zero) {
        self.statuses = statuses
        self.duration = duration
    }

    private var cleared: [String] = []
    var clears: [String] { lock.withLock { cleared } }

    func clear(id: String, report: @Sendable (PlaygroundComponentStatus) -> Void) async {
        lock.withLock { cleared.append(id) }
        report(PlaygroundComponentStatus(id: id, state: .cleared))
    }

    var requests: [PlaygroundComponentRequest] { lock.withLock { presented } }
    var didOverlap: Bool { lock.withLock { overlapped } }

    func present(
        _ request: PlaygroundComponentRequest,
        report: @Sendable (PlaygroundComponentStatus) -> Void
    ) async {
        lock.withLock {
            presented.append(request)
            running += 1
            if running > 1 { overlapped = true }
        }
        for state in statuses {
            report(PlaygroundComponentStatus(id: request.id, state: state))
        }
        try? await Task.sleep(for: duration)
        lock.withLock { running -= 1 }
    }
}
