import Foundation

protocol SnapshotSchemeDiscovering {
    func discoverSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [String]
}

struct SnapshotSchemeDiscoverer: SnapshotSchemeDiscovering {
    let fileSystem: FileSystemProvider

    func discoverSnapshotTestSchemes(
        repoRoot: String,
        projectFileName: String,
        spmPackagesContainerPath: String
    ) throws -> [String] {
        let repoRootURL = URL(fileURLWithPath: repoRoot, isDirectory: true)
        let projectSchemesDirectory = repoRootURL
            .appendingPathComponent(projectFileName, isDirectory: true)
            .appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)

        var schemeNames: [String] = []

        if fileSystem.fileExists(atPath: projectSchemesDirectory.path) {
            let projectSchemeFiles = try fileSystem.contentsOfDirectory(
                at: projectSchemesDirectory,
                includingPropertiesForKeys: nil,
                options: []
            )
            schemeNames.append(contentsOf: contentsOfXCSchemes(from: projectSchemeFiles))
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
            schemeNames.append(contentsOf: contentsOfXCSchemes(from: packageSchemeFiles))
        }

        return uniquePreservingOrder(schemeNames).sorted()
    }

    private func contentsOfXCSchemes(from urls: [URL]) -> [String] {
        urls
            .filter { $0.pathExtension == "xcscheme" }
            .map { $0.deletingPathExtension().lastPathComponent }
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
