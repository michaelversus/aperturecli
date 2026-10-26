import Foundation
import Testing
@testable import NSAssetsCLI

struct HarnessAssetValidatorTests {
    private let logo = "/repo/App/Assets.xcassets/logo.imageset"

    @Test
    func anExistingImagesetInsideACatalogIsAccepted() {
        let validator = HarnessAssetValidator(fileSystem: MockFileSystem(existingPaths: [logo]))

        let diagnostics = validator.diagnostics(for: [entry(.imageset, logo)])

        #expect(diagnostics.isEmpty)
    }

    @Test
    func anImagesetInAGroupFolderInsideACatalogIsAccepted() {
        let path = "/repo/Assets.xcassets/Icons/logo.imageset"
        let validator = HarnessAssetValidator(fileSystem: MockFileSystem(existingPaths: [path]))

        #expect(validator.diagnostics(for: [entry(.imageset, path)]).isEmpty)
    }

    @Test(arguments: [
        ("/repo/Assets.xcassets/logo.png", PlaygroundAssetEntry.Kind.imageset),
        ("/repo/Assets.xcassets/brand.colorset", .imageset),
        ("/repo/Assets.xcassets/logo.imageset", .colorset),
        ("/repo/Other/logo.imageset", .imageset),
        ("/repo/Assets.xcassets/../Secrets/logo.imageset", .imageset),
        ("Assets.xcassets/logo.imageset", .imageset),
        ("/repo/Assets.xcassets/.imageset", .imageset)
    ])
    func anythingElseIsRefusedWithAHarnessDiagnostic(path: String, kind: PlaygroundAssetEntry.Kind) {
        let validator = HarnessAssetValidator(fileSystem: MockFileSystem(existingPaths: [path]))

        let diagnostics = validator.diagnostics(for: [entry(kind, path)])

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.file == .harness)
        #expect(diagnostics.first?.severity == .error)
    }

    @Test
    func aFolderThatDoesNotExistIsRefused() {
        let validator = HarnessAssetValidator(fileSystem: MockFileSystem())

        let diagnostics = validator.diagnostics(for: [entry(.imageset, logo)])

        #expect(diagnostics.first?.message.contains("does not exist") == true)
    }

    private func entry(_ kind: PlaygroundAssetEntry.Kind, _ path: String) -> PlaygroundAssetEntry {
        PlaygroundAssetEntry(catalog: "Assets", kind: kind, path: path)
    }
}
