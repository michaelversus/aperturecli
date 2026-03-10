import Foundation
import Testing
@testable import ApertureCLI

struct ApertureConfigWriterTests {
    @Test
    func configExistsLooksUpApertureConfigPath() {
        let fileSystem = MockFileSystem(existingPaths: ["/repo/.aperture.json"])
        let writer = ApertureConfigWriter(fileSystem: fileSystem)

        #expect(writer.configExists(at: "/repo"))
        #expect(fileSystem.fileExistsCalls == ["/repo/.aperture.json"])
    }

    @Test
    func writeSerializesConfigToExpectedPath() throws {
        let fileSystem = MockFileSystem()
        let writer = ApertureConfigWriter(fileSystem: fileSystem)
        let config = ApertureConfig(
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
        #expect(write.path == "/repo/.aperture.json")

        let data = try #require(write.contents.data(using: .utf8))
        let decoded = try JSONDecoder().decode(ApertureConfig.self, from: data)
        #expect(decoded.projectFileName == "MyApp.xcodeproj")
        #expect(decoded.snapshotTestSchemes == ["Snapshots"])
    }
}
