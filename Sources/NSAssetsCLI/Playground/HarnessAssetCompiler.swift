import CryptoKit
import Foundation

enum HarnessAssetError: Error, Equatable {
    case refused([PlaygroundDiagnostic])
    case compilerFailed(output: String)
}

/// Compiles the entries into `Assets.car` inside the harness app, so `Bundle.main` lookups resolve.
///
/// The entries are copied into a minimal `Assets.xcassets` in the harness directory and compiled with `actool`. The
/// work is skipped while the entries, their files and the deployment target are unchanged. A request without entries
/// removes what an earlier request left behind.
struct HarnessAssetCompiler {
    let fileSystem: FileSystemProvider
    let commandRunner: CommandRunning
    let harnessDirectory: String

    private var catalogPath: String { harnessDirectory + "/Assets.xcassets" }
    private var fingerprintPath: String { harnessDirectory + "/assets.fingerprint" }
    private func compiledPath(in appBundle: String) -> String { appBundle + "/Assets.car" }

    func prepare(_ entries: [PlaygroundAssetEntry], target: HarnessTarget, appBundle: String) throws {
        guard !entries.isEmpty else {
            try removeCompiledAssets(in: appBundle)
            return
        }
        let refused = HarnessAssetValidator(fileSystem: fileSystem).diagnostics(for: entries)
        guard refused.isEmpty else { throw HarnessAssetError.refused(refused) }

        let unique = uniqueEntries(entries)
        let fingerprint = fingerprint(of: unique, target: target)
        if fileSystem.fileExists(atPath: compiledPath(in: appBundle)),
           (try? fileSystem.readFile(atPath: fingerprintPath)) == fingerprint {
            return
        }

        try writeCatalog(unique)
        try compile(target: target, appBundle: appBundle)
        try fileSystem.writeFile(fingerprint, toPath: fingerprintPath)
    }

    private func removeCompiledAssets(in appBundle: String) throws {
        for path in [compiledPath(in: appBundle), fingerprintPath] where fileSystem.fileExists(atPath: path) {
            try fileSystem.removeItem(atPath: path)
        }
    }

    /// The bundle is looked up by name only, so the first entry of a name and kind wins.
    private func uniqueEntries(_ entries: [PlaygroundAssetEntry]) -> [PlaygroundAssetEntry] {
        var seen = Set<String>()
        return entries.filter { seen.insert("\($0.name).\($0.kind.rawValue)").inserted }
    }

    private func writeCatalog(_ entries: [PlaygroundAssetEntry]) throws {
        if fileSystem.fileExists(atPath: catalogPath) {
            try fileSystem.removeItem(atPath: catalogPath)
        }
        try fileSystem.createDirectory(atPath: catalogPath, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            #"{"info":{"author":"xcode","version":1}}"#,
            toPath: catalogPath + "/Contents.json"
        )
        for entry in entries {
            try fileSystem.copyItem(
                atPath: HarnessAssetValidator.resolvedPath(of: entry),
                toPath: "\(catalogPath)/\(entry.name).\(entry.kind.rawValue)"
            )
        }
    }

    private func compile(target: HarnessTarget, appBundle: String) throws {
        do {
            _ = try commandRunner.run(
                executable: ExternalTools.xcrun,
                arguments: [
                    "actool", catalogPath, "--compile", appBundle,
                    "--platform", "iphonesimulator",
                    "--minimum-deployment-target", target.iOSVersion,
                    "--target-device", "iphone", "--target-device", "ipad",
                    "--output-partial-info-plist", harnessDirectory + "/assets-partial.plist"
                ]
            )
        } catch let SubprocessRunnerError.commandFailed(_, _, _, output) {
            throw HarnessAssetError.compilerFailed(output: output)
        }
    }

    /// Changes whenever an entry, one of its files or the deployment target does, so edited artwork is picked up.
    private func fingerprint(of entries: [PlaygroundAssetEntry], target: HarnessTarget) -> String {
        var lines = [target.iOSVersion]
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        for entry in entries {
            let path = HarnessAssetValidator.resolvedPath(of: entry)
            lines.append("\(entry.catalog)|\(entry.kind.rawValue)|\(path)")
            let files = (try? fileSystem.recursiveContentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: keys,
                options: []
            )) ?? []
            for file in files.sorted(by: { $0.path < $1.path }) {
                let values = try? file.resourceValues(forKeys: Set(keys))
                let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                lines.append("\(file.path)|\(modified)|\(values?.fileSize ?? 0)")
            }
        }
        let digest = SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
