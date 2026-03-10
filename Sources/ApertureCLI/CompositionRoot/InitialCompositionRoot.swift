import Foundation
import ArgumentParser

struct InitialCompositionRoot {
    let fileSystem: FileSystemProvider

    func run() async throws {
        let repoRoot = fileSystem.currentDirectoryPath()
        let iosVersion = try promptRequiredValue("iOS version (for example: 18.2)")
        let simulatorModel = try promptRequiredValue("Simulator model (for example: iPhone 16 Pro)")
        let xcodeVersion = try promptRequiredValue("Xcode version (for example: 16.2)")
        let projectFileName = try promptRequiredValue("Project file name (for example: MyApp.xcodeproj)")

        let config = ApertureConfig(
            repoRoot: repoRoot,
            iosVersion: iosVersion,
            simulatorModel: simulatorModel,
            xcodeVersion: xcodeVersion,
            projectFileName: projectFileName
        )

        try write(config: config, at: repoRoot)
        await ApertureRuntimeMemory.shared.setCurrentConfig(config)

        print("Saved configuration to \(repoRoot)/.aperture.json")
    }

    private func promptRequiredValue(_ prompt: String) throws -> String {
        while true {
            print("\(prompt): ", terminator: "")
            guard let rawInput = readLine() else {
                throw CleanExit.message("Input closed before setup completed.")
            }

            let value = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }

            print("Value cannot be empty. Please try again.")
        }
    }

    private func write(config: ApertureConfig, at rootPath: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(config)
        let configURL = URL(fileURLWithPath: rootPath).appendingPathComponent(".aperture.json")
        try data.write(to: configURL, options: .atomic)
    }
}
