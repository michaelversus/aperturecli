import Testing
@testable import NSAssetsCLI

struct HarnessSDKModulesTests {
    private let modules = HarnessSDKModules(
        sdkPath: "/sdk",
        fileSystem: MockFileSystem(existingPaths: [
            "/sdk/System/Library/Frameworks/UIKit.framework",
            "/sdk/usr/lib/swift/Observation.swiftmodule"
        ])
    )

    @Test
    func aFrameworkInTheSDKIsASystemModule() {
        #expect(modules.isSystemModule("UIKit"))
    }

    @Test
    func aSwiftOnlyModuleInTheSDKIsASystemModule() {
        #expect(modules.isSystemModule("Observation"))
    }

    @Test
    func aModuleTheSDKDoesNotShipIsNot() {
        #expect(!modules.isSystemModule("DesignSystem"))
    }
}
