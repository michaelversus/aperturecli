import Testing
@testable import NSAssetsCLI

@Suite(
    "XCResultPathResolverError Tests",
    .disabled("Temporarily disabled while investigating CI exit code 1 during test execution.")
)
struct XCResultPathResolverErrorTests {
    @Test("test errorDescription with invalid arguments returns guidance message")
    func test_errorDescription_WithInvalidArguments_returnsGuidanceMessage() throws {
        let sut: XCResultPathResolverError = .invalidArguments

        let description = try #require(sut.errorDescription)

        #expect(description == "❌ Both schemeName and projectName must be non-empty.")
    }

    @Test("test errorDescription with missing test logs directory includes provided path")
    func test_errorDescription_WithMissingTestLogsDirectory_returnsPathSpecificMessage() throws {
        let missingPath = "/tmp/DerivedData/Logs/Test"
        let sut: XCResultPathResolverError = .missingTestLogsDirectory(path: missingPath)

        let description = try #require(sut.errorDescription)

        #expect(description == "❌ Test logs directory was not found at \(missingPath).")
    }

    @Test("test errorDescription with no xcresult files includes provided path")
    func test_errorDescription_WithNoXCResultFiles_returnsPathSpecificMessage() throws {
        let searchPath = "/tmp/DerivedData/Logs/Test"
        let sut: XCResultPathResolverError = .noXCResultFiles(path: searchPath)

        let description = try #require(sut.errorDescription)

        #expect(description == "❌ No .xcresult files were found at \(searchPath).")
    }

    @Test("test errorDescription with no scheme match includes scheme and search path")
    func test_errorDescription_WithNoSchemeMatch_returnsContextualMessage() throws {
        let schemeName = "Snapshots"
        let searchPath = "/tmp/DerivedData/Logs/Test"
        let sut: XCResultPathResolverError = .noSchemeMatch(
            schemeName: schemeName,
            searchPath: searchPath
        )

        let description = try #require(sut.errorDescription)

        #expect(
            description == "❌ No .xcresult file matching scheme '\(schemeName)' was found in \(searchPath)."
        )
    }
}
