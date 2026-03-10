import Foundation
import ArgumentParser

protocol ApertureConfigLoading {
    func load(atRootPath rootPath: String) throws -> ApertureConfig
}

struct ApertureConfigLoader: ApertureConfigLoading {
    let fileSystem: FileSystemProvider

    func load(atRootPath rootPath: String) throws -> ApertureConfig {
        let configPath = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(".aperture.json")
            .path

        guard fileSystem.fileExists(atPath: configPath) else {
            throw CleanExit.message(
                "Configuration file not found at \(configPath). Run `aperture init` first."
            )
        }

        let contents = try fileSystem.readFile(atPath: configPath)
        guard let data = contents.data(using: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return try JSONDecoder().decode(ApertureConfig.self, from: data)
    }
}
