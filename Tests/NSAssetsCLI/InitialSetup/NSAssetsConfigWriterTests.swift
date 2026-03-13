import Foundation
import Testing
@testable import NSAssetsCLI

struct NSAssetsConfigWriterTests {
    @Test
    func configExistsLooksUpNSAssetsConfigPath() {
        let fileSystem = MockFileSystem(existingPaths: ["/repo/.nsassets.json"])
        let writer = NSAssetsConfigWriter(fileSystem: fileSystem)

        #expect(writer.configExists(at: "/repo"))
        #expect(fileSystem.fileExistsCalls == ["/repo/.nsassets.json"])
    }

    @Test
    func writeSerializesConfigToExpectedPath() throws {
        let fileSystem = MockFileSystem()
        let writer = NSAssetsConfigWriter(fileSystem: fileSystem)
        let config = NSAssetsConfig(
            repoRoot: "/repo",
            iosVersion: "18.2",
            simulatorModel: "iPhone 16 Pro",
            xcodeVersion: "16.2",
            projectFileName: "MyApp.xcodeproj",
            spmPackagesContainerPath: "Packages",
            snapshotTestSchemes: ["Snapshots"]
        )

        try writer.write(config, at: "/repo")

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.path == "/repo/.nsassets.json")

        let data = try #require(write.contents.data(using: .utf8))
        let decoded = try JSONDecoder().decode(NSAssetsConfig.self, from: data)
        #expect(decoded.projectFileName == "MyApp.xcodeproj")
        #expect(decoded.snapshotTestSchemes == ["Snapshots"])
    }
}
