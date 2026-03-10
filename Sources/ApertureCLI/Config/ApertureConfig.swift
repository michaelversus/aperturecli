import Foundation

struct ApertureConfig: Codable, Sendable {
    let repoRoot: String
    let iosVersion: String
    let simulatorModel: String
    let xcodeVersion: String
    let projectFileName: String
}

actor ApertureRuntimeMemory {
    static let shared = ApertureRuntimeMemory()

    private(set) var currentConfig: ApertureConfig?

    func setCurrentConfig(_ config: ApertureConfig) {
        currentConfig = config
    }
}
