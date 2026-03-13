import Foundation
import Testing
@testable import NSAssetsCLI

struct NSAssetsConfigTests {
    @Test
    func decodingUsesDefaultsForOptionalFields() throws {
        let data = Data("""
        {
          "repoRoot": "/repo",
          "iosVersion": "18.2",
          "simulatorModel": "iPhone 16 Pro",
          "xcodeVersion": "16.2",
          "projectFileName": "MyApp.xcodeproj"
        }
        """.utf8)

        let config = try JSONDecoder().decode(NSAssetsConfig.self, from: data)

        #expect(config.spmPackagesContainerPath == "Packages")
        #expect(config.snapshotTestSchemes.isEmpty)
    }

    @Test
    func encodingRoundTripsExplicitValues() throws {
        let config = NSAssetsConfig(
            repoRoot: "/repo",
            iosVersion: "18.2",
            simulatorModel: "iPhone 16 Pro",
            xcodeVersion: "16.2",
            projectFileName: "MyApp.xcodeproj",
            spmPackagesContainerPath: "Vendor/Packages",
            snapshotTestSchemes: ["Snapshots"]
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(NSAssetsConfig.self, from: data)

        #expect(decoded.repoRoot == config.repoRoot)
        #expect(decoded.projectFileName == config.projectFileName)
        #expect(decoded.projectName == "MyApp")
        #expect(decoded.spmPackagesContainerPath == config.spmPackagesContainerPath)
        #expect(decoded.snapshotTestSchemes == config.snapshotTestSchemes)
    }
}
