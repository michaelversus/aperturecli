protocol HarnessBuilding: Sendable {
    func build(_ request: PlaygroundComponentRequest, target: HarnessTarget) throws -> HarnessBuildResult
}
