import Foundation
import Testing
@testable import NSAssetsCLI

struct SimulatorTapVerifierTests {
    private let point = NormalizedPoint(horizontal: 0.5, vertical: 0.3)

    @Test
    func tapIsDeliveredWhenTheScreenChangesAndNoEventIsDropped() async throws {
        let session = MockSimulatorSession(probeResult: supportedProbe)
        let observer = MockSimulatorScreenObserver(digests: ["before", "after"])
        let verifier = SimulatorTapVerifier(observer: observer, settleDuration: .zero)

        let delivery = try await verifier.verify(tap: point, on: session)

        #expect(delivery == .delivered)
        #expect(await session.calls == [.tap(point)])
    }

    @Test
    func tapIsNotDeliveredWhenTheScreenDoesNotChange() async throws {
        let session = MockSimulatorSession(probeResult: supportedProbe)
        let observer = MockSimulatorScreenObserver(digests: ["same", "same"])
        let verifier = SimulatorTapVerifier(observer: observer, settleDuration: .zero)

        let delivery = try await verifier.verify(tap: point, on: session)

        #expect(delivery == .notDelivered(.screenUnchanged))
    }

    @Test
    func droppedEventsInTheLogMeanNotDeliveredEvenIfTheScreenChanged() async throws {
        let session = MockSimulatorSession(probeResult: supportedProbe)
        let line = "No active service, dropping event"
        let observer = MockSimulatorScreenObserver(digests: ["before", "after"], droppedLines: [line])
        let verifier = SimulatorTapVerifier(observer: observer, settleDuration: .zero)

        let delivery = try await verifier.verify(tap: point, on: session)

        #expect(delivery == .notDelivered(.eventsDropped([line])))
    }

    private var supportedProbe: SimulatorProbeResult {
        SimulatorProbeResult(
            status: .supported,
            xcodeVersion: "27.1",
            coreSimulatorVersion: "1155.4",
            issues: []
        )
    }
}
