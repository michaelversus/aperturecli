import Foundation

/// Collects what a command printed so a test can assert on it.
final class OutputRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    var text: String { lock.withLock { lines.joined(separator: "\n") } }

    func record(_ line: String) {
        lock.withLock { lines.append(line) }
    }
}
