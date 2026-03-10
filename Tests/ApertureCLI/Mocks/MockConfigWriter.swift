@testable import ApertureCLI

final class MockConfigWriter: ApertureConfigWriting {
    let configExistsValue: Bool

    private(set) var configExistsCalls: [String] = []
    private(set) var writeCallCount = 0
    private(set) var writtenConfig: ApertureConfig?
    private(set) var writtenRootPath: String?

    init(configExists: Bool) {
        self.configExistsValue = configExists
    }

    func configExists(at rootPath: String) -> Bool {
        configExistsCalls.append(rootPath)
        return configExistsValue
    }

    func write(_ config: ApertureConfig, at rootPath: String) throws {
        writeCallCount += 1
        writtenConfig = config
        writtenRootPath = rootPath
    }
}
