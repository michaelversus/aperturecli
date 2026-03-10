import Testing
@testable import ApertureCLI

struct SchemePostActionSynchronizerTests {
    @Test
    func syncsOnlySelectedSchemesAndReportsMissingSelections() throws {
        let discoverer = MockSnapshotSchemeDiscoverer(
            locatedSchemes: [
                SchemeReference(
                    name: "Snapshots",
                    path: "/repo/MyApp.xcodeproj/xcshareddata/xcschemes/Snapshots.xcscheme",
                    source: .project
                ),
                SchemeReference(
                    name: "Snapshots",
                    path: "/repo/Packages/Foo/.swiftpm/xcode/xcshareddata/xcschemes/Snapshots.xcscheme",
                    source: .spm
                ),
                SchemeReference(
                    name: "Other",
                    path: "/repo/MyApp.xcodeproj/xcshareddata/xcschemes/Other.xcscheme",
                    source: .project
                )
            ]
        )
        let updater = MockSchemePostActionUpdater()
        let synchronizer = SchemePostActionSynchronizer(
            schemeDiscoverer: discoverer,
            schemeUpdater: updater
        )

        let result = try synchronizer.syncPostActions(
            repoRoot: "/repo",
            projectFileName: "MyApp.xcodeproj",
            spmPackagesContainerPath: "Packages",
            selectedSchemeNames: ["Snapshots", "Missing"]
        )

        #expect(discoverer.locateCallCount == 1)
        #expect(updater.calls.count == 2)
        #expect(updater.calls.map(\.schemeName) == ["Snapshots", "Snapshots"])
        #expect(result.matchedSchemeNames == ["Snapshots"])
        #expect(result.updatedSchemeFileCount == 2)
        #expect(result.missingSelectedSchemeNames == ["Missing"])
    }
}
