import Foundation
import Testing
@testable import ApertureCLI

struct SnapshotSchemeDiscovererTests {
    @Test
    func discoversProjectAndPackageSchemesAndReturnsUniqueSortedNames() throws {
        let projectSchemesURL = URL(fileURLWithPath: "/repo/MyApp.xcodeproj/xcshareddata/xcschemes", isDirectory: true)
        let packagesURL = URL(fileURLWithPath: "/repo/Packages", isDirectory: true)
        let fileSystem = MockFileSystem(
            existingPaths: [
                projectSchemesURL.path,
                packagesURL.path
            ],
            directoryContentsByPath: [
                projectSchemesURL.path: [
                    projectSchemesURL.appendingPathComponent("Snapshots.xcscheme"),
                    projectSchemesURL.appendingPathComponent("Shared.xcscheme"),
                    projectSchemesURL.appendingPathComponent("README.md")
                ]
            ],
            recursiveDirectoryContentsByPath: [
                packagesURL.path: [
                    URL(fileURLWithPath: "/repo/Packages/Foo/.swiftpm/xcode/xcshareddata/xcschemes/Shared.xcscheme"),
                    URL(fileURLWithPath: "/repo/Packages/Bar/.swiftpm/xcode/xcshareddata/xcschemes/PackageSnapshots.xcscheme")
                ]
            ]
        )
        let discoverer = SnapshotSchemeDiscoverer(fileSystem: fileSystem)

        let schemes = try discoverer.discoverSnapshotTestSchemes(
            repoRoot: "/repo",
            projectFileName: "MyApp.xcodeproj",
            spmPackagesContainerPath: "Packages"
        )

        #expect(schemes == ["PackageSnapshots", "Shared", "Snapshots"])
    }
}
