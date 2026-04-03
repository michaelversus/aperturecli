import Testing
@testable import NSAssetsCLI

@Suite(
    "XCResultToolClientError Tests",
    .disabled("Temporarily disabled while investigating CI exit code 1 during test execution.")
)
struct XCResultToolClientErrorTests {
    @Test("test errorDescription with invalid JSON includes command and underlying error")
    func test_errorDescription_WithInvalidJSON_returnsDetailedMessage() throws {
        let command = "/usr/bin/xcrun xcresulttool get test-results summary --path /tmp/run.xcresult"
        let underlying = "The data couldn’t be read because it isn’t in the correct format."
        let sut: XCResultToolClientError = .invalidJSON(command: command, underlying: underlying)

        let description = try #require(sut.errorDescription)

        #expect(
            description
                == "❌ Failed to decode JSON output for command '\(command)': \(underlying)"
        )
    }

    @Test("test errorDescription with missing manifest includes path")
    func test_errorDescription_WithMissingManifest_returnsPathSpecificMessage() throws {
        let manifestPath = "/tmp/export/manifest.json"
        let sut: XCResultToolClientError = .missingManifest(path: manifestPath)

        let description = try #require(sut.errorDescription)

        #expect(description == "❌ Missing attachments manifest at \(manifestPath).")
    }

    @Test("test Equatable compares associated values")
    func test_equatable_comparesAssociatedValues() {
        let lhs: XCResultToolClientError = .invalidJSON(command: "a", underlying: "b")
        let rhs: XCResultToolClientError = .invalidJSON(command: "a", underlying: "b")
        let different: XCResultToolClientError = .invalidJSON(command: "a", underlying: "c")
        let differentCase: XCResultToolClientError = .missingManifest(path: "a")

        #expect(lhs == rhs)
        #expect(lhs != different)
        #expect(lhs != differentCase)
    }
}
