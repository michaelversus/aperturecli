import Foundation

/// Lets a test wait for a server to report the port it bound.
final class PortSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt16?

    var port: UInt16? { lock.withLock { value } }

    func set(_ port: UInt16) {
        lock.withLock { value = port }
    }
}
