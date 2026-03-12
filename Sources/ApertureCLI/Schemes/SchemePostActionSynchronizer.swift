import Foundation

protocol SchemePostActionSynchronizing {
    func syncPostActions(
        repoRoot: String,
        projectFileName: String,
        projectName: String,
        spmPackagesContainerPath: String,
        selectedSchemeNames: [String]
    ) throws -> SchemePostActionSyncResult
}

struct SchemePostActionSynchronizer: SchemePostActionSynchronizing {
    let schemeDiscoverer: SnapshotSchemeDiscovering
    let schemeUpdater: SchemePostActionUpdating

    func syncPostActions(
        repoRoot: String,
        projectFileName: String,
        projectName: String,
        spmPackagesContainerPath: String,
        selectedSchemeNames: [String]
    ) throws -> SchemePostActionSyncResult {
        let selectedNames = uniquePreservingOrder(selectedSchemeNames)
        let selectedNameSet = Set(selectedNames)
        let references = try schemeDiscoverer.locateSnapshotTestSchemes(
            repoRoot: repoRoot,
            projectFileName: projectFileName,
            spmPackagesContainerPath: spmPackagesContainerPath
        )

        let matchedReferences = references.filter { selectedNameSet.contains($0.name) }
        for reference in matchedReferences {
            try schemeUpdater.updatePostAction(
                at: reference.path,
                schemeName: reference.name,
                projectName: projectName
            )
        }

        let matchedSchemeNames = uniquePreservingOrder(matchedReferences.map(\.name))
        let matchedSchemeSet = Set(matchedSchemeNames)
        let missingSchemeNames = selectedNames.filter { !matchedSchemeSet.contains($0) }

        return SchemePostActionSyncResult(
            matchedSchemeNames: matchedSchemeNames,
            updatedSchemeFilePaths: matchedReferences.map(\.path),
            missingSelectedSchemeNames: missingSchemeNames
        )
    }

    private func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values where seen.insert(value).inserted {
            result.append(value)
        }

        return result
    }
}
