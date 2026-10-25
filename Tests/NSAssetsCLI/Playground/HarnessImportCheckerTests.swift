import Testing
@testable import NSAssetsCLI

struct HarnessImportCheckerTests {
    private let checker = HarnessImportChecker(isSystemModule: { ["SwiftUI", "UIKit", "Foundation"].contains($0) })

    @Test
    func systemImportsProduceNoDiagnostics() {
        let source = "import SwiftUI\nimport UIKit\nimport Foundation\nstruct A {}"

        #expect(checker.diagnostics(forSource: source).isEmpty)
    }

    @Test
    func anImportOutsideTheSDKIsAClearDiagnosticOnItsLine() throws {
        let source = "import SwiftUI\nimport DesignSystem\nstruct A {}"

        let diagnostic = try #require(checker.diagnostics(forSource: source).first)

        #expect(diagnostic.file == .component)
        #expect(diagnostic.line == 2)
        #expect(diagnostic.severity == .error)
        #expect(diagnostic.message.contains("DesignSystem"))
        #expect(diagnostic.message.contains("inline"))
    }

    @Test(arguments: [
        "@testable import Core",
        "import struct Core.Money",
        "public import Core",
        "  import Core.Submodule",
        "@_exported import Core"
    ])
    func everyImportFormNamesItsModuleRoot(line: String) throws {
        let diagnostic = try #require(checker.diagnostics(forSource: line).first)

        #expect(diagnostic.message.contains("'Core'"))
    }

    @Test
    func everyNonSystemImportIsReported() {
        let source = "import A\nimport B\nimport A"

        #expect(checker.diagnostics(forSource: source).count == 3)
    }

    @Test
    func codeThatMerelyMentionsImportIsNotAnImport() {
        let source = "let important = \"import Nothing\"\n// import Commented\nstruct ImportantView {}"

        #expect(checker.diagnostics(forSource: source).isEmpty)
    }
}
