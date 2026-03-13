import Foundation
import ArgumentParser

protocol NSAssetsConfigLoading {
    func load(atRootPath rootPath: String) throws -> NSAssetsConfig
}

struct NSAssetsConfigLoader: NSAssetsConfigLoading {
    let fileSystem: FileSystemProvider

    func load(atRootPath rootPath: String) throws -> NSAssetsConfig {
        let configPath = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(".nsassets.json")
            .path

        guard fileSystem.fileExists(atPath: configPath) else {
            throw CleanExit.message(
                "Configuration file not found at \(configPath). Run `nsassets init` first."
            )
        }

        let contents = try fileSystem.readFile(atPath: configPath)
        guard let data = contents.data(using: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return try JSONDecoder().decode(NSAssetsConfig.self, from: data)
    }
}
