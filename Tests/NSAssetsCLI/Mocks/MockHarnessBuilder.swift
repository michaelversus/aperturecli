import Foundation
@testable import NSAssetsCLI

final class MockHarnessBuilder: HarnessBuilding, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(request: PlaygroundComponentRequest, target: HarnessTarget)] = []
    private let result: Result<HarnessBuildResult, any Error>
    let isWarm: Bool

    init(result: Result<HarnessBuildResult, any Error>, isWarm: Bool = true) {
        self.result = result
        self.isWarm = isWarm
    }

    var builds: [(request: PlaygroundComponentRequest, target: HarnessTarget)] { lock.withLock { recorded } }

    func build(_ request: PlaygroundComponentRequest, target: HarnessTarget) throws -> HarnessBuildResult {
        lock.withLock { recorded.append((request, target)) }
        return try result.get()
    }
}
