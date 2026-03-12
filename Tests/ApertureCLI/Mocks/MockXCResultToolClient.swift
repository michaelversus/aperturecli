import Foundation
@testable import ApertureCLI

final class MockXCResultToolClient: XCResultToolProviding {
    struct TestInvocation: Equatable {
        let xcresultPath: String
        let testIdentifier: String
    }

    struct ExportInvocation: Equatable {
        let xcresultPath: String
        let testIdentifier: String
        let outputPath: String
    }

    typealias SummaryHandler = (String) throws -> XCResultToolModels.Summary
    typealias TestHandler = (String, String) throws -> XCResultToolModels.TestDetails
    typealias ActivitiesHandler = (String, String) throws -> XCResultToolModels.TestActivities
    typealias ExportHandler = (String, String, String) throws -> [XCResultToolModels.ExportedAttachmentManifestEntry]

    private(set) var fetchSummaryCalls: [String] = []
    private(set) var fetchTestDetailsCalls: [TestInvocation] = []
    private(set) var fetchTestActivitiesCalls: [TestInvocation] = []
    private(set) var exportAttachmentsCalls: [ExportInvocation] = []

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
        fetchTestDetailsCalls.append(
            TestInvocation(xcresultPath: xcresultPath, testIdentifier: testIdentifier)
        )
        return try testDetailsHandler(xcresultPath, testIdentifier)
    }

    func fetchTestActivities(
        xcresultPath: String,
        testIdentifier: String
    ) throws -> XCResultToolModels.TestActivities {
        fetchTestActivitiesCalls.append(
            TestInvocation(xcresultPath: xcresultPath, testIdentifier: testIdentifier)
        )
        return try testActivitiesHandler(xcresultPath, testIdentifier)
    }

    func exportAttachments(
        xcresultPath: String,
        testIdentifier: String,
        outputPath: String
    ) throws -> [XCResultToolModels.ExportedAttachmentManifestEntry] {
        exportAttachmentsCalls.append(
            ExportInvocation(
                xcresultPath: xcresultPath,
                testIdentifier: testIdentifier,
                outputPath: outputPath
            )
        )
        return try exportHandler(xcresultPath, testIdentifier, outputPath)
    }
}
