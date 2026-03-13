import Testing
@testable import NSAssetsCLI

@Suite("XCResultPathResolverError Tests")
struct XCResultPathResolverErrorTests {
    @Test("errorDescription for invalid arguments returns guidance message")
    func errorDescriptionForInvalidArgumentsReturnsGuidanceMessage() throws {
        let sut: XCResultPathResolverError = .invalidArguments

        let description = try #require(sut.errorDescription)

        #expect(description == "❌ Both schemeName and projectName must be non-empty.")
    }

    @Test("errorDescription for missing test logs includes path")
    func errorDescriptionForMissingTestLogsIncludesPath() throws {
        let path = "/tmp/Logs/Test"
        let sut: XCResultPathResolverError = .missingTestLogsDirectory(path: path)

        let description = try #require(sut.errorDescription)

        #expect(description == "❌ Test logs directory was not found at \(path).")
    }

    @Test("errorDescription for missing xcresult files includes path")
    func errorDescriptionForMissingXCResultFilesIncludesPath() throws {
        let path = "/tmp/Logs/Test"
        let sut: XCResultPathResolverError = .noXCResultFiles(path: path)

        let description = try #require(sut.errorDescription)

        #expect(description == "❌ No .xcresult files were found at \(path).")
    }

    @Test("errorDescription for missing scheme match includes scheme and search path")
    func errorDescriptionForMissingSchemeMatchIncludesSchemeAndSearchPath() throws {
        let schemeName = "Snapshots"
        let searchPath = "/tmp/Logs/Test"
        let sut: XCResultPathResolverError = .noSchemeMatch(
            schemeName: schemeName,
            searchPath: searchPath
        )

        let description = try #require(sut.errorDescription)

        #expect(
            description
                == "❌ No .xcresult file matching scheme '\(schemeName)' was found in \(searchPath)."
        )
    }
}
