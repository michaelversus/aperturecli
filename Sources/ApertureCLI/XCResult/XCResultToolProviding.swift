import Foundation

protocol XCResultToolProviding {
    func fetchSummary(xcresultPath: String) throws -> XCResultToolModels.Summary
    func fetchTestDetails(
        xcresultPath: String,
        testIdentifier: String
    ) throws -> XCResultToolModels.TestDetails
    func fetchTestActivities(
        xcresultPath: String,
        testIdentifier: String
    ) throws -> XCResultToolModels.TestActivities
    func exportAttachments(
        xcresultPath: String,
        testIdentifier: String,
        outputPath: String
    ) throws -> [XCResultToolModels.ExportedAttachmentManifestEntry]
}
