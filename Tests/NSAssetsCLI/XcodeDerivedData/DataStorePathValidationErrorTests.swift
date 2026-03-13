import Testing
@testable import NSAssetsCLI

@Suite("DataStorePathValidationError Tests")
struct DataStorePathValidationErrorTests {
    @Test("test errorDescription with invalid path includes provided path")
    func test_errorDescription_WithInvalidPath_returnsPathSpecificMessage() throws {
        // Given
        let invalidPath = "/tmp/MissingDataStore"
        let sut: DataStorePathValidationError = .invalidPath(invalidPath)

        // When
        let description = try #require(sut.errorDescription)

        // Then
        #expect(description == "❌ The provided DataStore path does not exist: \(invalidPath).")
    }
}
