import Foundation

/// Refuses anything that is not a `.imageset` or `.colorset` folder inside a `.xcassets` catalog, because the CLI copies
/// what it is given into the harness and must not be pointed at arbitrary files.
struct HarnessAssetValidator {
    let fileSystem: FileSystemProvider

    func diagnostics(for entries: [PlaygroundAssetEntry]) -> [PlaygroundDiagnostic] {
        entries.compactMap { entry in
            if let problem = problem(with: entry) {
                return .harnessError("Asset \"\(entry.path)\" was refused: \(problem).")
            }
            return nil
        }
    }

    /// The entry's location with `.` and `..` resolved, which is what gets checked and copied.
    static func resolvedPath(of entry: PlaygroundAssetEntry) -> String {
        URL(fileURLWithPath: entry.path).standardizedFileURL.path
    }

    private func problem(with entry: PlaygroundAssetEntry) -> String? {
        guard entry.path.hasPrefix("/") else { return "the path is not absolute" }
        let folder = URL(fileURLWithPath: Self.resolvedPath(of: entry))
        guard folder.pathExtension == entry.kind.rawValue, !folder.deletingPathExtension().lastPathComponent.isEmpty else {
            return "it is not a .\(entry.kind.rawValue) folder"
        }
        let insideCatalog = folder.deletingLastPathComponent().pathComponents.contains { $0.hasSuffix(".xcassets") }
        guard insideCatalog else { return "it is not inside a .xcassets catalog" }
        guard fileSystem.fileExists(atPath: folder.path) else { return "it does not exist" }
        return nil
    }
}
