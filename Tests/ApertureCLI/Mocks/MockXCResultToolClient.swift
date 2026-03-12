import Foundation
@testable import ApertureCLI

final class MockXCResultToolClient: XCResultToolProviding {
    typealias SummaryHandler = (String) throws -> XCResultToolModels.Summary
    typealias TestHandler = (String, String) throws -> XCResultToolModels.TestDetails
    typealias ActivitiesHandler = (String, String) throws -> XCResultToolModels.TestActivities
    typealias ExportHandler = (String, String, String) throws -> [XCResultToolModels.ExportedAttachmentManifestEntry]

    private(set) var fetchSummaryCalls: [String] = []
    private(set) var fetchTestDetailsCalls: [(xcresultPath: String, testIdentifier: String)] = []
    private(set) var fetchTestActivitiesCalls: [(xcresultPath: String, testIdentifier: String)] = []
    private(set) var exportAttachmentsCalls: [(xcresultPath: String, testIdentifier: String, outputPath: String)] = []

    var summaryHandler: SummaryHandler
    var testDetailsHandler: TestHandler
    var testActivitiesHandler: ActivitiesHandler
    var exportHandler: ExportHandler

    init(
        summaryHandler: @escaping SummaryHandler,
        testDetailsHandler: @escaping TestHandler = { _, _ in
            XCResultToolModels.TestDetails(
                duration: nil,
                durationInSeconds: nil,
                hasMediaAttachments: nil,
                hasPerformanceMetrics: nil,
                startTime: nil,
                testDescription: nil,
                testIdentifier: nil,
                testIdentifierURL: nil,
                testName: nil,
                testResult: nil
            )
        },
        testActivitiesHandler: @escaping ActivitiesHandler = { _, _ in
            XCResultToolModels.TestActivities(
                testIdentifier: nil,
                testIdentifierURL: nil,
                testName: nil,
                testRuns: []
            )
        },
        exportHandler: @escaping ExportHandler = { _, _, _ in [] }
    ) {
        self.summaryHandler = summaryHandler
        self.testDetailsHandler = testDetailsHandler
        self.testActivitiesHandler = testActivitiesHandler
        self.exportHandler = exportHandler
    }

    func fetchSummary(xcresultPath: String) throws -> XCResultToolModels.Summary {
        fetchSummaryCalls.append(xcresultPath)
        return try summaryHandler(xcresultPath)
    }

    func fetchTestDetails(
        xcresultPath: String,
        testIdentifier: String
    ) throws -> XCResultToolModels.TestDetails {
        fetchTestDetailsCalls.append((xcresultPath, testIdentifier))
        return try testDetailsHandler(xcresultPath, testIdentifier)
    }

    func fetchTestActivities(
        xcresultPath: String,
        testIdentifier: String
    ) throws -> XCResultToolModels.TestActivities {
        fetchTestActivitiesCalls.append((xcresultPath, testIdentifier))
        return try testActivitiesHandler(xcresultPath, testIdentifier)
    }

    func exportAttachments(
        xcresultPath: String,
        testIdentifier: String,
        outputPath: String
    ) throws -> [XCResultToolModels.ExportedAttachmentManifestEntry] {
        exportAttachmentsCalls.append((xcresultPath, testIdentifier, outputPath))
        return try exportHandler(xcresultPath, testIdentifier, outputPath)
    }
}

