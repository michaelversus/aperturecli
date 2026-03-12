import Foundation

struct SyncPostActionsCommandExecutor {
    let fileSystem: FileSystemProvider
    let configLoader: ApertureConfigLoading
    let synchronizer: SchemePostActionSynchronizing
    let output: (String) -> Void

    func run() throws {
        let currentRoot = fileSystem.currentDirectoryPath()
        let config = try configLoader.load(atRootPath: currentRoot)
        let result = try synchronizer.syncPostActions(
            repoRoot: config.repoRoot,
            projectFileName: config.projectFileName,
            projectName: config.projectName,
            spmPackagesContainerPath: config.spmPackagesContainerPath,
            selectedSchemeNames: config.snapshotTestSchemes
        )

        for line in SchemePostActionSyncReporting.lines(for: result) {
            output(line)
        }
    }
}
