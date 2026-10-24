import Foundation

/// Sends one tap and decides whether it landed, since the common failure is a call that succeeds
/// while the guest silently drops the event.
struct SimulatorTapVerifier {
    let observer: any SimulatorScreenObserving
    let settleDuration: Duration

    func verify(tap point: NormalizedPoint, on session: any SimulatorSession) async throws -> SimulatorTapDelivery {
        let before = try await observer.screenDigest()
        let start = Date()
        try await session.tap(at: point)
        try await Task.sleep(for: settleDuration)
        let after = try await observer.screenDigest()
        let dropped = try await observer.droppedEventLogLines(since: start)

        if !dropped.isEmpty { return .notDelivered(.eventsDropped(dropped)) }
        return before == after ? .notDelivered(.screenUnchanged) : .delivered
    }
}
