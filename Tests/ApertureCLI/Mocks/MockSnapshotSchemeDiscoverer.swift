@testable import ApertureCLI

final class MockSnapshotSchemeDiscoverer: SnapshotSchemeDiscovering {
    let discoveredSchemes: [String]

    private(set) var callCount = 0
    private(set) var receivedRepoRoot: String?
    private(set) var receivedProjectFileName: String?
    private(set) var receivedSPMPackagesPath: String?

    init(discoveredSchemes: [String] = []) {
        self.discoveredSchemes = discoveredSchemes
    }

    func discoverSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [String] {
        callCount += 1
        receivedRepoRoot = repoRoot
        receivedProjectFileName = projectFileName
        receivedSPMPackagesPath = spmPackagesContainerPath
        return discoveredSchemes
    }
}
