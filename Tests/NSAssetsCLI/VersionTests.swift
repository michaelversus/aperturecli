import Testing
@testable import NSAssetsCLI

struct VersionTests {
    @Test
    func exposesCurrentVersion() {
        #expect(version == "1.0.0")
    }
}
