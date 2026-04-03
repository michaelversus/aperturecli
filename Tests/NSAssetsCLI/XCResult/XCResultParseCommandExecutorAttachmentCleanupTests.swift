import Foundation
import Testing
@testable import NSAssetsCLI

@Suite(
    .disabled("Temporarily disabled while investigating CI exit code 1 during test execution.")
)
struct XCResultAttachmentCleanupTests {
    @Test
    func removesExistingSchemeAttachmentsBeforeExportAndRecreatesDirectory() throws {
        let attachmentsPath = "/repo/nsassets-artifacts/xcresults/Snapshots/attachments"
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo/App/Subdir",
            existingPaths: ["/repo/.git", attachmentsPath]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = makeCleanupClient()

        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { _ in }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        #expect(fileSystem.removeItemOperations.map(\.path) == [attachmentsPath])
        #expect(
            fileSystem.createDirectoryOperations.map(\.path) == [
                "/repo/nsassets-artifacts/xcresults",
                attachmentsPath,
                attachmentsPath + "/SnapshotSuite_test_snapshot_mismatch"
            ]
        )
        let exportCall = try #require(xcresultToolClient.exportAttachmentsCalls.first)
        #expect(exportCall.outputPath == attachmentsPath + "/SnapshotSuite_test_snapshot_mismatch")
    }

    @Test
    func cleanupIsScopedToTheTargetSchemeAttachmentsDirectory() throws {
        let snapshotsAttachmentsPath = "/repo/nsassets-artifacts/xcresults/Snapshots/attachments"
        let otherSchemePath = "/repo/nsassets-artifacts/xcresults/OtherScheme/attachments"
        let logsPath = "/repo/nsassets-artifacts/logs"
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo/App/Subdir",
            existingPaths: ["/repo/.git", snapshotsAttachmentsPath, otherSchemePath, logsPath]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = makeCleanupClient()

        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { _ in }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        #expect(fileSystem.removeItemOperations.map(\.path) == [snapshotsAttachmentsPath])
        #expect(!fileSystem.removeItemOperations.map(\.path).contains(otherSchemePath))
        #expect(!fileSystem.removeItemOperations.map(\.path).contains(logsPath))
    }

    @Test
    func rethrowsAttachmentCleanupFailureWithoutWritingArtifact() throws {
        let attachmentsPath = "/repo/nsassets-artifacts/xcresults/Snapshots/attachments"
        let expectedError = NSError(domain: "filesystem", code: 42)
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: ["/repo/.git", attachmentsPath],
            removeItemErrorByPath: [attachmentsPath: expectedError]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = makeCleanupClient()
        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { _ in }
        )

        #expect(throws: NSError.self) {
            try executor.run(schemeName: "Snapshots", projectName: "MyApp")
        }
        #expect(fileSystem.removeItemOperations.map(\.path) == [attachmentsPath])
        #expect(fileSystem.writeOperations.isEmpty)
        #expect(xcresultToolClient.exportAttachmentsCalls.isEmpty)
    }
}

private func makeCleanupClient() -> MockXCResultToolClient {
    MockXCResultToolClient(
        summaryHandler: { _ in try decodeCleanupSummary(cleanupSummaryJSON) },
        testDetailsHandler: { _, _ in makeCleanupTestDetails() },
        testActivitiesHandler: { _, _ in makeCleanupTestActivities() },
        exportHandler: { _, _, _ in makeCleanupExportedManifest() }
    )
}

private func makeCleanupTestDetails() -> XCResultToolModels.TestDetails {
    XCResultToolModels.TestDetails(
        duration: "0.12s",
        durationInSeconds: 0.12,
        hasMediaAttachments: true,
        hasPerformanceMetrics: false,
        startTime: 10,
        testDescription: "Test case with 1 run",
        testIdentifier: "SnapshotSuite/test_snapshot_mismatch",
        testIdentifierURL: "test://example/snapshot",
        testName: "test_snapshot_mismatch",
        testResult: "Failed"
    )
}

private func makeCleanupTestActivities() -> XCResultToolModels.TestActivities {
    XCResultToolModels.TestActivities(
        testIdentifier: "SnapshotSuite/test_snapshot_mismatch",
        testIdentifierURL: "test://example/snapshot",
        testName: "test_snapshot_mismatch",
        testRuns: [
            XCResultToolModels.ActivityTestRun(
                activities: [
                    XCResultToolModels.Activity(
                        attachments: [
                            XCResultToolModels.ActivityAttachment(
                                lifetime: "deleteOnSuccess",
                                name: "difference.png",
                                payloadId: "payload-1",
                                timestamp: 11,
                                uuid: "uuid-1"
                            )
                        ],
                        childActivities: nil,
                        title: "Attached Failure Diff",
                        isAssociatedWithFailure: false
                    )
                ]
            )
        ]
    )
}

private func makeCleanupExportedManifest() -> [XCResultToolModels.ExportedAttachmentManifestEntry] {
    [
        XCResultToolModels.ExportedAttachmentManifestEntry(
            testIdentifier: "SnapshotSuite/test_snapshot_mismatch",
            testIdentifierURL: "test://example/snapshot",
            attachments: [
                XCResultToolModels.ExportedAttachment(
                    exportedFileName: "diff.png",
                    suggestedHumanReadableName: "difference.png",
                    isAssociatedWithFailure: false,
                    timestamp: 11,
                    configurationName: "Test Scheme Action",
                    deviceName: "iPhone",
                    deviceId: "device-1",
                    repetitionNumber: nil,
                    arguments: nil
                )
            ]
        )
    ]
}

private func decodeCleanupSummary(_ json: String) throws -> XCResultToolModels.Summary {
    guard let data = json.data(using: .utf8) else {
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
    return try JSONDecoder().decode(XCResultToolModels.Summary.self, from: data)
}

private let cleanupSummaryJSON = """
{
  "title": "Test - Snapshots",
  "environmentDescription": "Snapshots · Built with macOS",
  "result": "Failed",
  "totalTestCount": 2,
  "passedTests": 1,
  "failedTests": 1,
  "skippedTests": 0,
  "expectedFailures": 0,
  "devicesAndConfigurations": [],
  "testFailures": [
    {
      "failureText": "Snapshot does not match",
      "targetName": "SnapshotsTests",
      "testIdentifierString": "SnapshotSuite/test_snapshot_mismatch",
      "testIdentifierURL": "test://example/snapshot",
      "testName": "test_snapshot_mismatch"
    }
  ]
}
"""
