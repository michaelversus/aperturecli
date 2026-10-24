struct SimulatorProbeResult: Sendable, Equatable {
    let status: SimulatorProbeStatus
    let xcodeVersion: String
    let coreSimulatorVersion: String?
    let issues: [SimulatorProbeIssue]
}
