@testable import ApertureCLI

final class MockApertureConfigLoader: ApertureConfigLoading {
    var config: ApertureConfig
    var error: Error?

    private(set) var receivedRootPath: String?
    private(set) var loadCallCount = 0

    init(config: ApertureConfig) {
        self.config = config
    }

    func load(atRootPath rootPath: String) throws -> ApertureConfig {
        loadCallCount += 1
        receivedRootPath = rootPath
        if let error {
            throw error
        }
        return config
    }
}
