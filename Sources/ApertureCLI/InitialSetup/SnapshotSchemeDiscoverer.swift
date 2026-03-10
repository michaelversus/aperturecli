import Foundation

protocol SnapshotSchemeDiscovering {
    func locateSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [SchemeReference]

    func discoverSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [String]
}

struct SnapshotSchemeDiscoverer: SnapshotSchemeDiscovering {
    let fileSystem: FileSystemProvider

    func locateSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [SchemeReference] {
        let repoRootURL = URL(fileURLWithPath: repoRoot, isDirectory: true)
        let projectSchemesDirectory = repoRootURL
            .appendingPathComponent(projectFileName, isDirectory: true)
            .appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)

        var references: [SchemeReference] = []

        if fileSystem.fileExists(atPath: projectSchemesDirectory.path) {
            let projectSchemeFiles = try fileSystem.contentsOfDirectory(
                at: projectSchemesDirectory,
                includingPropertiesForKeys: nil,
                options: []
            )
            references.append(contentsOf: schemeReferences(from: projectSchemeFiles, source: .project))
        }

        let spmPackagesContainerURL = resolvePath(spmPackagesContainerPath, relativeTo: repoRootURL)
        if fileSystem.fileExists(atPath: spmPackagesContainerURL.path) {
            let packageItems = try fileSystem.recursiveContentsOfDirectory(
                at: spmPackagesContainerURL,
                includingPropertiesForKeys: nil,
                options: []
            )
            let packageSchemeFiles = packageItems.filter { itemURL in
                let normalizedPath = itemURL.standardizedFileURL.path
                return normalizedPath.contains("/.swiftpm/xcode/xcshareddata/xcschemes/")
            }
            references.append(contentsOf: schemeReferences(from: packageSchemeFiles, source: .spm))
        }

        return references
    }

    func discoverSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [String] {
        let references = try locateSnapshotTestSchemes(
            repoRoot: repoRoot,
            projectFileName: projectFileName,
            spmPackagesContainerPath: spmPackagesContainerPath
        )
        return uniquePreservingOrder(references.map(\.name)).sorted()
    }

    private func schemeReferences(from urls: [URL], source: SchemeSource) -> [SchemeReference] {
        urls
            .filter { $0.pathExtension == "xcscheme" }
            .map {
                SchemeReference(
                    name: $0.deletingPathExtension().lastPathComponent,
                    path: $0.path,
                    source: source
                )
            }
    }

    private func resolvePath(_ path: String, relativeTo rootURL: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return rootURL.appendingPathComponent(path, isDirectory: true)
    }

    private func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var uniqueValues: [String] = []

        for value in values where seen.insert(value).inserted {
            uniqueValues.append(value)
        }

        return uniqueValues
    }
}
