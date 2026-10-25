/// The only seam in front of the private simulator APIs, so everything above it can be faked.
protocol SimulatorSession: Sendable {
    func probe() async -> SimulatorProbeResult
    /// Boots the simulator if needed, opens the input connection and waits until it is ready.
    func start() async throws
    func frames() -> AsyncThrowingStream<SimulatorFrame, Error>
    func tap(at point: NormalizedPoint) async throws
    /// One step of a gesture: a finger going down, moving or lifting. A gesture is `start`, any `position`s, `end`.
    func touch(_ phase: SimulatorTouchPhase, at point: NormalizedPoint) async throws
    /// A key going down or up, named by its USB HID keyboard usage.
    func key(usage: UInt64, isDown: Bool) async throws
    func stop() async
}
