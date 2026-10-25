import CryptoKit
import Foundation

enum HarnessCacheLocator {
    /// One harness directory per repository, so components from different repositories never rebuild each other's.
    static func directory(forWorkingDirectory workingDirectory: String, libraryDirectory: URL) -> String {
        let digest = SHA256.hash(data: Data(workingDirectory.utf8))
        let key = digest.map { String(format: "%02x", $0) }.joined().prefix(12)
        return libraryDirectory
            .appendingPathComponent("Caches/NSAssetsCLI/playground/\(key)", isDirectory: true)
            .path
    }
}
