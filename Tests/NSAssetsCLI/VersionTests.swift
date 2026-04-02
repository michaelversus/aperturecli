import Foundation
import Testing
@testable import NSAssetsCLI

struct VersionTests {
    @Test
    func cliVersionMatchesVersionFile() throws {
        let versionFileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("VERSION", isDirectory: false)
        let expectedVersion = try String(contentsOf: versionFileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(version == expectedVersion)
        #expect(NSAssetsCLI.configuration.version == expectedVersion)
    }
}
