import Foundation

/// Runs async work one item after another, in the order it was added, from any thread.
/// `@unchecked Sendable` is safe because the only mutable state, `last`, is guarded by `lock`.
final class SerialTaskQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var last: Task<Void, Never>?

    func enqueue(_ work: @escaping @Sendable () async -> Void) {
        lock.withLock {
            let previous = last
            last = Task {
                await previous?.value
                await work()
            }
        }
    }
}
