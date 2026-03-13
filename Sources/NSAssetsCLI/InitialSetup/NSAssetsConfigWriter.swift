import Foundation

protocol NSAssetsConfigWriting {
    func configExists(at rootPath: String) -> Bool
    func write(_ config: NSAssetsConfig, at rootPath: String) throws
}

struct NSAssetsConfigWriter: NSAssetsConfigWriting {
    let fileSystem: FileSystemProvider

    func configExists(at rootPath: String) -> Bool {
        fileSystem.fileExists(atPath: configFilePath(at: rootPath))
    }

    func write(_ config: NSAssetsConfig, at rootPath: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(config)
        guard let contents = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        try fileSystem.writeFile(contents, toPath: configFilePath(at: rootPath))
    }

    private func configFilePath(at rootPath: String) -> String {
        URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(".nsassets.json")
            .path
    }
}
