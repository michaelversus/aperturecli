import Foundation

/// Performs a tap from a client, checking it first when a verifier is set, and reports failures to the terminal.
struct PlaygroundTapRunner: Sendable {
    let session: any SimulatorSession
    let verifier: SimulatorTapVerifier?
    let output: @Sendable (String) -> Void

    func run(_ point: NormalizedPoint) async {
        do {
            if let verifier {
                output(try await verifier.verify(tap: point, on: session).summary)
            } else {
                try await session.tap(at: point)
            }
        } catch {
            output("Tap failed: \(error.localizedDescription)")
        }
    }
}
