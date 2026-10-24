/// The only seam in front of the private simulator APIs, so everything above it can be faked.
protocol SimulatorSession: Sendable {
    func probe() async -> SimulatorProbeResult
    /// Boots the simulator if needed, opens the input connection and waits until it is ready.
    func start() async throws
    func frames() -> AsyncThrowingStream<SimulatorFrame, Error>
    func tap(at point: NormalizedPoint) async throws
    func stop() async
}
