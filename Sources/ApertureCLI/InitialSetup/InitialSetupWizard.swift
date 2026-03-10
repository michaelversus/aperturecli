import Foundation
import ArgumentParser

struct InitialSetupWizard {
    let fileSystem: FileSystemProvider
    let prompter: InitialSetupPrompting
    let schemeDiscoverer: SnapshotSchemeDiscovering
    let configWriter: ApertureConfigWriting

    func run() async throws {
        let repoRoot = fileSystem.currentDirectoryPath()
        let repoRootURL = URL(fileURLWithPath: repoRoot, isDirectory: true)

        if configWriter.configExists(at: repoRoot) {
            let shouldReplace = try prompter.promptConfirmation(
                ".aperture.json already exists. Replace it?",
                defaultValue: false
            )

            if shouldReplace {
                prompter.writeMessage("Replacing existing configuration.")
            } else {
                prompter.writeMessage("Keeping existing configuration. Setup cancelled.")
                throw CleanExit.message("Setup cancelled.")
            }
        }

        let iosVersion = try prompter.promptRequiredValue("iOS version (for example: 18.2)")
        let simulatorModel = try prompter.promptRequiredValue("Simulator model (for example: iPhone 16 Pro)")
        let xcodeVersion = try prompter.promptRequiredValue("Xcode version (for example: 16.2)")
        let projectFileName = try promptExistingProjectFileName(relativeTo: repoRootURL)
        let spmPackagesContainerPath = try promptExistingPathValue(
            "Local SPM packages container path (for example: Packages)",
            relativeTo: repoRootURL
        )
        let discoveredSchemes = try await prompter.performWithSpinner(
            prefix: "Scanning for available schemes",
            operation: {
                try schemeDiscoverer.discoverSnapshotTestSchemes(
                    repoRoot: repoRoot,
                    projectFileName: projectFileName,
                    spmPackagesContainerPath: spmPackagesContainerPath
                )
            }
        )
        let snapshotTestSchemes = try prompter.promptSnapshotTestSchemes(from: discoveredSchemes)

        let config = ApertureConfig(
            repoRoot: repoRoot,
            iosVersion: iosVersion,
            simulatorModel: simulatorModel,
            xcodeVersion: xcodeVersion,
            projectFileName: projectFileName,
            spmPackagesContainerPath: spmPackagesContainerPath,
            snapshotTestSchemes: snapshotTestSchemes
        )

        try configWriter.write(config, at: repoRoot)
        prompter.writeMessage("Saved configuration to \(repoRoot)/.aperture.json")
    }

    private func promptExistingPathValue(_ prompt: String, relativeTo rootURL: URL) throws -> String {
        while true {
            let value = try prompter.promptRequiredValue(prompt)
            let resolvedURL = resolvePath(value, relativeTo: rootURL)
            if fileSystem.fileExists(atPath: resolvedURL.path) {
                return value
            }
            prompter.writeMessage("Path does not exist: \(value). Please try again.")
        }
    }

    private func promptExistingProjectFileName(relativeTo rootURL: URL) throws -> String {
        while true {
            let value = try prompter.promptRequiredValue("Project name (for example: MyApp)")
            let projectFileName = value.hasSuffix(".xcodeproj") ? value : "\(value).xcodeproj"
            let resolvedURL = resolvePath(projectFileName, relativeTo: rootURL)
            if fileSystem.fileExists(atPath: resolvedURL.path) {
                return projectFileName
            }
            prompter.writeMessage("Project file does not exist: \(projectFileName). Please try again.")
        }
    }

    private func resolvePath(_ path: String, relativeTo rootURL: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return rootURL.appendingPathComponent(path, isDirectory: true)
    }
}
