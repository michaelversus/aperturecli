struct PlaygroundCommandExecutor {
    let session: any SimulatorSession
    let output: @Sendable (String) -> Void

    init(session: any SimulatorSession, output: @escaping @Sendable (String) -> Void) {
        self.session = session
        self.output = output
    }

    /// Prints to standard output, as every spike command does.
    init(session: any SimulatorSession) {
        self.init(session: session, output: { Swift.print($0) })
    }

    @discardableResult
    func probe() async -> SimulatorProbeResult {
        let probe = await session.probe()
        printProbe(probe)
        return probe
    }

    func run(_ body: (any SimulatorSession) async throws -> Void) async throws {
        let probe = await probe()

        guard probe.status != .unsupported else {
            throw PlaygroundError.unsupported
        }

        try await session.start()
        do {
            try await body(session)
        } catch {
            await session.stop()
            throw error
        }
        await session.stop()
    }

    private func printProbe(_ probe: SimulatorProbeResult) {
        output("Simulator probe: \(probe.status.rawValue)")
        let coreSimulator = probe.coreSimulatorVersion ?? "unknown"
        output("Xcode \(probe.xcodeVersion), CoreSimulator \(coreSimulator)")
        for issue in probe.issues {
            output("- \(issue.message)")
        }
    }
}
