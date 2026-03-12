@testable import ApertureCLI

final class MockSchemePostActionSynchronizer: SchemePostActionSynchronizing {
    var result: SchemePostActionSyncResult
    var error: Error?

    private(set) var callCount = 0
    private(set) var receivedRepoRoot: String?
    private(set) var receivedProjectFileName: String?
    private(set) var receivedProjectName: String?
    private(set) var receivedSPMPackagesPath: String?
    private(set) var receivedSelectedSchemeNames: [String]?

    init(
        result: SchemePostActionSyncResult = SchemePostActionSyncResult(
            matchedSchemeNames: [],
            updatedSchemeFilePaths: [],
            missingSelectedSchemeNames: []
        ),
        error: Error? = nil
    ) {
        self.result = result
        self.error = error
    }

    func syncPostActions(
        repoRoot: String,
        projectFileName: String,
        projectName: String,
        spmPackagesContainerPath: String,
        selectedSchemeNames: [String]
    ) throws -> SchemePostActionSyncResult {
        callCount += 1
        receivedRepoRoot = repoRoot
        receivedProjectFileName = projectFileName
        receivedProjectName = projectName
        receivedSPMPackagesPath = spmPackagesContainerPath
        receivedSelectedSchemeNames = selectedSchemeNames

        if let error {
            throw error
        }

        return result
    }
}
