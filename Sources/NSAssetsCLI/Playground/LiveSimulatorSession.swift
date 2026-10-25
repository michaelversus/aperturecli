import Foundation

/// Talks to a real, explicitly chosen simulator through private APIs. Without a UDID it can only probe.
actor LiveSimulatorSession: SimulatorSession {
    private static let tapHoldDuration = Duration.milliseconds(60)
    private static let buttonHoldDuration = Duration.milliseconds(100)

    let udid: String?
    private var touchSender: DTUHIDTouchSender?
    private var frameSource: FramebufferFrameSource?

    init(udid: String?) {
        self.udid = udid
    }

    func probe() async -> SimulatorProbeResult {
        let inspector = SimulatorEnvironmentInspector()
        let facts = inspector.inspect(udid: udid)
        guard let udid, let developerDirectory = inspector.resolveDeveloperDirectory(),
              let device = try? SimulatorDeviceHandle.find(udid: udid, developerDirectory: developerDirectory),
              device.isBooted,
              let ioClient = try? device.ioClient()
        else { return SimulatorProbeClassifier.classify(facts) }

        let framebuffer = await FramebufferProbe.run(ioClient: ioClient)
        let screenSize = try? SimctlScreenObserver(udid: udid).screenSizeInPixels()
        let sizeMatches: Bool? = screenSize.map {
            framebuffer.frameWidthInPixels == $0.width && framebuffer.frameHeightInPixels == $0.height
        }
        return SimulatorProbeClassifier.classify(
            facts.withFramebuffer(
                portFound: framebuffer.portFound,
                surfaceMatchesNativeSize: framebuffer.portFound ? sizeMatches : nil,
                displayCount: framebuffer.displayCount
            )
        )
    }

    func start() async throws {
        guard let udid else { throw PlaygroundError.deviceNotFound("no --udid given") }
        let inspector = SimulatorEnvironmentInspector()
        guard let developerDirectory = inspector.resolveDeveloperDirectory() else {
            throw PlaygroundError.serviceContextUnavailable("no developer directory")
        }
        let device = try SimulatorDeviceHandle.find(udid: udid, developerDirectory: developerDirectory)
        guard device.isBooted else { throw PlaygroundError.deviceNotBooted(udid) }
        frameSource = FramebufferFrameSource(ioClient: try device.ioClient())

        touchSender = try await DTUHIDTouchSender.connect(to: device)
    }

    nonisolated func frames() -> AsyncThrowingStream<SimulatorFrame, Error> {
        AsyncThrowingStream { continuation in
            let relay = Task {
                do {
                    for try await frame in try await self.makeFrameStream() { continuation.yield(frame) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in relay.cancel() }
        }
    }

    private func makeFrameStream() throws -> AsyncThrowingStream<SimulatorFrame, Error> {
        guard let frameSource else { throw PlaygroundError.sessionNotStarted }
        return frameSource.frames()
    }

    func tap(at point: NormalizedPoint) async throws {
        try await touch(.start, at: point)
        try await Task.sleep(for: Self.tapHoldDuration)
        try await touch(.end, at: point)
    }

    func touch(_ phase: SimulatorTouchPhase, at point: NormalizedPoint) async throws {
        guard let touchSender else { throw PlaygroundError.sessionNotStarted }
        try await touchSender.send(phase, at: point)
    }

    func key(usage: UInt64, isDown: Bool) async throws {
        guard let touchSender else { throw PlaygroundError.sessionNotStarted }
        try await touchSender.sendKey(usage: usage, isDown: isDown)
    }

    func press(_ button: SimulatorHardwareButton) async throws {
        guard let touchSender else { throw PlaygroundError.sessionNotStarted }
        guard let usage = button.consumerUsage else {
            for step in SimulatorHomeGesture.steps {
                try await touchSender.send(step.phase, at: step.point, edge: SimulatorHomeGesture.bottomEdge)
                try await Task.sleep(for: SimulatorHomeGesture.stepInterval)
            }
            return
        }
        try await touchSender.sendButton(usagePage: DTUHIDTouchSender.consumerUsagePage, usage: usage, isDown: true)
        try await Task.sleep(for: Self.buttonHoldDuration)
        try await touchSender.sendButton(usagePage: DTUHIDTouchSender.consumerUsagePage, usage: usage, isDown: false)
    }

    func stop() async {
        await touchSender?.disconnect()
        touchSender = nil
        frameSource = nil
    }
}
