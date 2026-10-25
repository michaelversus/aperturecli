protocol HarnessBuilding: Sendable {
    /// Whether this repository's harness has been built before, so the next build is the quick, incremental one.
    var isWarm: Bool { get }

    func build(_ request: PlaygroundComponentRequest, target: HarnessTarget) throws -> HarnessBuildResult
}
