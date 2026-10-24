import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundCommandExecutorTests {
    @Test
    func unsupportedProbeRefusesToStartAndPrintsTheIssues() async throws {
        let session = MockSimulatorSession(
            probeResult: makeResult(status: .unsupported, issues: [.simulatorKitNotFound])
        )
        let output = OutputRecorder()
        var bodyRan = false
        let executor = PlaygroundCommandExecutor(session: session, output: output.record)

        await #expect(throws: PlaygroundError.unsupported) {
            try await executor.run { _ in bodyRan = true }
        }

        #expect(bodyRan == false)
        #expect(await session.calls == [.probe])
        #expect(output.text.contains("unsupported"))
        #expect(output.text.contains("SimulatorKit"))
    }

    @Test
    func degradedProbeStartsRunsTheBodyAndStops() async throws {
        let session = MockSimulatorSession(
            probeResult: makeResult(status: .degraded, issues: [.multipleDisplays])
        )
        let output = OutputRecorder()
        let executor = PlaygroundCommandExecutor(session: session, output: output.record)

        try await executor.run { session in
            try await session.tap(at: NormalizedPoint(horizontal: 0.5, vertical: 0.25))
        }

        #expect(await session.calls == [.probe, .start, .tap(NormalizedPoint(horizontal: 0.5, vertical: 0.25)), .stop])
        #expect(output.text.contains("degraded"))
        #expect(output.text.contains("displays"))
    }

    @Test
    func stopsTheSessionWhenTheBodyThrows() async {
        struct BodyFailure: Error {}
        let session = MockSimulatorSession(probeResult: makeResult(status: .supported, issues: []))
        let executor = PlaygroundCommandExecutor(session: session, output: { _ in })

        await #expect(throws: BodyFailure.self) {
            try await executor.run { _ in throw BodyFailure() }
        }

        #expect(await session.calls == [.probe, .start, .stop])
    }

    @Test
    func printsTheDeviceHubRepairCommandWithoutRunningIt() async throws {
        let repair = "xcrun simctl spawn UDID-1 notifyutil -s com.apple.coredevice.dtuhidd.active 0"
        let session = MockSimulatorSession(
            probeResult: makeResult(status: .degraded, issues: [.deviceHubAttached(repairCommand: repair)])
        )
        let output = OutputRecorder()
        let executor = PlaygroundCommandExecutor(session: session, output: output.record)

        try await executor.run { _ in }

        #expect(output.text.contains(repair))
        #expect(output.text.contains("not run"))
    }

    @Test
    func doesNotStopASessionThatFailedToStart() async {
        struct StartFailure: Error {}
        let session = MockSimulatorSession(
            probeResult: makeResult(status: .supported, issues: []),
            startError: StartFailure()
        )
        let executor = PlaygroundCommandExecutor(session: session, output: { _ in })

        await #expect(throws: StartFailure.self) {
            try await executor.run { _ in }
        }

        #expect(await session.calls == [.probe, .start])
    }
}

private final class OutputRecorder: @unchecked Sendable {
    private(set) var lines: [String] = []
    var text: String { lines.joined(separator: "\n") }
    func record(_ line: String) { lines.append(line) }
}

private func makeResult(
    status: SimulatorProbeStatus,
    issues: [SimulatorProbeIssue]
) -> SimulatorProbeResult {
    SimulatorProbeResult(
        status: status,
        xcodeVersion: "27.1",
        coreSimulatorVersion: "1155.4",
        issues: issues
    )
}
