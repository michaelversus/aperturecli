import Foundation
@testable import NSAssetsCLI

final class MockHarnessBuilder: HarnessBuilding, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(request: PlaygroundComponentRequest, target: HarnessTarget)] = []
    private let result: Result<HarnessBuildResult, any Error>

    init(result: Result<HarnessBuildResult, any Error>) {
        self.result = result
    }

    var builds: [(request: PlaygroundComponentRequest, target: HarnessTarget)] { lock.withLock { recorded } }

    func build(_ request: PlaygroundComponentRequest, target: HarnessTarget) throws -> HarnessBuildResult {
        lock.withLock { recorded.append((request, target)) }
        return try result.get()
    }
}
