import Foundation

/// Polls until `condition` holds or `timeout` passes, for assertions about work that happens on another queue.
func waitUntil(timeout: Duration = .seconds(3), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return false
}

/// Polls until `read` returns a value or `timeout` passes.
func waitForValue<T>(timeout: Duration = .seconds(3), _ read: () -> T?) async -> T? {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if let value = read() { return value }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return nil
}
