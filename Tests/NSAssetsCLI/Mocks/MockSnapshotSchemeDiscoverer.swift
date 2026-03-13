@testable import NSAssetsCLI

final class MockSnapshotSchemeDiscoverer: SnapshotSchemeDiscovering {
    let discoveredSchemes: [String]
    let locatedSchemes: [SchemeReference]

    private(set) var callCount = 0
    private(set) var locateCallCount = 0
    private(set) var receivedRepoRoot: String?
    private(set) var receivedProjectFileName: String?
    private(set) var receivedSPMPackagesPath: String?

    init(
        discoveredSchemes: [String] = [],
        locatedSchemes: [SchemeReference] = []
    ) {
        self.discoveredSchemes = discoveredSchemes
        self.locatedSchemes = locatedSchemes
    }

    func locateSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [SchemeReference] {
        locateCallCount += 1
        receivedRepoRoot = repoRoot
        receivedProjectFileName = projectFileName
        receivedSPMPackagesPath = spmPackagesContainerPath
        return locatedSchemes
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
