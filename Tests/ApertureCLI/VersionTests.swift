import Testing
@testable import ApertureCLI

struct VersionTests {
    @Test
    func exposesCurrentVersion() {
        #expect(version == "1.0.0")
    }
}
