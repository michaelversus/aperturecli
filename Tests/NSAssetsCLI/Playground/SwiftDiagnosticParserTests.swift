import Testing
@testable import NSAssetsCLI

struct SwiftDiagnosticParserTests {
    private let parser = SwiftDiagnosticParser(entryFirstLine: 7, entryLineCount: 3)

    @Test
    func anErrorInTheComponentKeepsTheLineOfTheCodeThatWasSent() throws {
        let output = "/cache/Sources/ComponentSource.swift:12:5: error: cannot find 'Foo' in scope"

        let diagnostic = try #require(parser.parse(output).first)

        #expect(diagnostic.file == .component)
        #expect(diagnostic.line == 12)
        #expect(diagnostic.column == 5)
        #expect(diagnostic.severity == .error)
        #expect(diagnostic.message == "cannot find 'Foo' in scope")
    }

    @Test
    func anErrorInTheEntryIsRelativeToTheEntryExpression() throws {
        let output = "/cache/Sources/PlaygroundEntry.swift:8:9: error: extra argument 'x' in call"

        let diagnostic = try #require(parser.parse(output).first)

        #expect(diagnostic.file == .entry)
        #expect(diagnostic.line == 2)
    }

    @Test
    func anErrorOnTheLastLineOfTheExpressionIsStillTheEntry() throws {
        let output = "/cache/Sources/PlaygroundEntry.swift:9:1: error: unexpected token"

        let diagnostic = try #require(parser.parse(output).first)

        #expect(diagnostic.file == .entry)
        #expect(diagnostic.line == 3)
    }

    @Test(arguments: [3, 6, 10, 11])
    func anErrorInTheGeneratedWrapperIsTheHarnessNotAnEntryLine(line: Int) throws {
        let output = "/cache/Sources/PlaygroundEntry.swift:\(line):1: error: something in the generated wrapper"

        let diagnostic = try #require(parser.parse(output).first)

        #expect(diagnostic.file == .harness)
        #expect(diagnostic.line == line)
    }

    @Test
    func anErrorInTheHarnessAppIsReportedAsTheHarness() throws {
        let output = "/cache/Sources/HarnessApp.swift:4:1: error: oops"

        #expect(try #require(parser.parse(output).first).file == .harness)
    }

    @Test
    func warningsAreKeptAndNotesAreDropped() {
        let output = """
        /cache/Sources/ComponentSource.swift:3:9: warning: variable 'x' was never used
        /cache/Sources/ComponentSource.swift:3:9: note: remove the variable
        """

        let diagnostics = parser.parse(output)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.severity == .warning)
    }

    @Test
    func anErrorWithoutALocationIsAHarnessDiagnostic() throws {
        let diagnostic = try #require(parser.parse("error: no such module 'Missing'").first)

        #expect(diagnostic.file == .harness)
        #expect(diagnostic.line == nil)
        #expect(diagnostic.message == "no such module 'Missing'")
    }

    @Test
    func unrelatedOutputProducesNothing() {
        #expect(parser.parse("Compiling Harness\n1 warning generated.").isEmpty)
    }
}
