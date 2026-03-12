import Foundation
import ArgumentParser

struct InitialSetupWizard {
    let fileSystem: FileSystemProvider
    let prompter: InitialSetupPrompting
    let schemeDiscoverer: SnapshotSchemeDiscovering
    let schemePostActionSynchronizer: SchemePostActionSynchronizing
    let configWriter: ApertureConfigWriting

    private struct SetupInput {
        let repoRoot: String
        let iosVersion: String
        let simulatorModel: String
        let xcodeVersion: String
        let projectFileName: String
        let spmPackagesContainerPath: String
        let snapshotTestSchemes: [String]
    }

    func run() async throws {
        let repoRoot = fileSystem.currentDirectoryPath()
        let repoRootURL = URL(fileURLWithPath: repoRoot, isDirectory: true)

        try confirmConfigReplacementIfNeeded(at: repoRoot)
        let input = try await collectSetupInput(repoRoot: repoRoot, repoRootURL: repoRootURL)
        try ensureLogArtifactsDirectoryExists(at: input.repoRoot)
        let syncResult = try await prompter.performWithSpinner(
            prefix: "Synchronizing scheme post-actions",
            operation: {
                try schemePostActionSynchronizer.syncPostActions(
                    repoRoot: input.repoRoot,
                    projectFileName: input.projectFileName,
                    projectName: URL(fileURLWithPath: input.projectFileName).deletingPathExtension().lastPathComponent,
                    spmPackagesContainerPath: input.spmPackagesContainerPath,
                    selectedSchemeNames: input.snapshotTestSchemes
                )
            }
        )
        SchemePostActionSyncReporting.lines(for: syncResult).forEach(prompter.writeMessage)

        let config = ApertureConfig(
            repoRoot: input.repoRoot,
            iosVersion: input.iosVersion,
            simulatorModel: input.simulatorModel,
            xcodeVersion: input.xcodeVersion,
            projectFileName: input.projectFileName,
            spmPackagesContainerPath: input.spmPackagesContainerPath,
            snapshotTestSchemes: input.snapshotTestSchemes
        )

        try configWriter.write(config, at: input.repoRoot)
        prompter.writeMessage("Saved configuration to \(input.repoRoot)/.aperture.json")
    }

    private func confirmConfigReplacementIfNeeded(at repoRoot: String) throws {
        guard configWriter.configExists(at: repoRoot) else {
            return
        }

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

    private func collectSetupInput(repoRoot: String, repoRootURL: URL) async throws -> SetupInput {
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

        return SetupInput(
            repoRoot: repoRoot,
            iosVersion: iosVersion,
            simulatorModel: simulatorModel,
            xcodeVersion: xcodeVersion,
            projectFileName: projectFileName,
            spmPackagesContainerPath: spmPackagesContainerPath,
            snapshotTestSchemes: snapshotTestSchemes
        )
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

    private func ensureLogArtifactsDirectoryExists(at repoRoot: String) throws {
        let logsDirectoryPath = URL(fileURLWithPath: repoRoot, isDirectory: true)
            .appendingPathComponent("aperture-artifacts", isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
            .path

        try fileSystem.createDirectory(
            atPath: logsDirectoryPath,
            withIntermediateDirectories: true
        )
    }
}
