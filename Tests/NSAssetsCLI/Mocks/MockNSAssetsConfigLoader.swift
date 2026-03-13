@testable import NSAssetsCLI

final class MockNSAssetsConfigLoader: NSAssetsConfigLoading {
    var config: NSAssetsConfig
    var error: Error?

    private(set) var receivedRootPath: String?
    private(set) var loadCallCount = 0

    init(config: NSAssetsConfig) {
        self.config = config
    }

    func load(atRootPath rootPath: String) throws -> NSAssetsConfig {
        loadCallCount += 1
        receivedRootPath = rootPath
        if let error {
            throw error
        }
        return config
    }
}
