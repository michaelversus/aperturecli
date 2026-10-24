import Foundation

/// Suspends until the surrounding task is cancelled, which is how a long-running command is told to stop.
func waitUntilCancelled() async {
    do {
        while true { try await Task.sleep(for: .seconds(3600)) }
    } catch {
        // Cancellation is the normal way to end waiting.
    }
}
