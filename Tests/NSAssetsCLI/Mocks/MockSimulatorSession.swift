import Foundation
@testable import NSAssetsCLI

actor MockSimulatorSession: SimulatorSession {
    enum Call: Equatable {
        case probe
        case start
        case tap(NormalizedPoint)
        case touch(SimulatorTouchPhase, NormalizedPoint)
        case key(usage: UInt64, isDown: Bool)
        case stop

        var isKey: Bool {
            if case .key = self { true } else { false }
        }

        var isTouch: Bool {
            if case .touch = self { true } else { false }
        }
    }

    private(set) var calls: [Call] = []

    private let probeResult: SimulatorProbeResult
    private let framesToEmit: [SimulatorFrame]
    private let startError: (any Error)?
    private let tapError: (any Error)?

    init(
        probeResult: SimulatorProbeResult,
        framesToEmit: [SimulatorFrame] = [],
        startError: (any Error)? = nil,
        tapError: (any Error)? = nil
    ) {
        self.probeResult = probeResult
        self.framesToEmit = framesToEmit
        self.startError = startError
        self.tapError = tapError
    }

    func probe() async -> SimulatorProbeResult {
        calls.append(.probe)
        return probeResult
    }

    func start() async throws {
        calls.append(.start)
        if let startError { throw startError }
    }

    nonisolated func frames() -> AsyncThrowingStream<SimulatorFrame, Error> {
        let frames = framesToEmit
        return AsyncThrowingStream { continuation in
            for frame in frames { continuation.yield(frame) }
            continuation.finish()
        }
    }

    func tap(at point: NormalizedPoint) async throws {
        calls.append(.tap(point))
        if let tapError { throw tapError }
    }

    func touch(_ phase: SimulatorTouchPhase, at point: NormalizedPoint) async throws {
        calls.append(.touch(phase, point))
        if let tapError { throw tapError }
    }

    func key(usage: UInt64, isDown: Bool) async throws {
        calls.append(.key(usage: usage, isDown: isDown))
        if let tapError { throw tapError }
    }

    func stop() async {
        calls.append(.stop)
    }
}
