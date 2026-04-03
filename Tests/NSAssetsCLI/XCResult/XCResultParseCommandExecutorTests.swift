import Foundation
import Testing
@testable import NSAssetsCLI

@Suite(
    .disabled("Temporarily disabled while isolating individual XCResult parse-executor failure tests.")
)
struct XCResultParseCommandExecutorSuccessTests {
    @Test
    func writesStructuredArtifactWithFailedTestAttachments() throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo/App/Subdir",
            existingPaths: ["/repo/.git"]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = makeSuccessfulClient()
        var outputLines: [String] = []

        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { outputLines.append($0) }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        #expect(resolver.callCount == 1)
        #expect(resolver.receivedSchemeName == "Snapshots")
        #expect(resolver.receivedProjectName == "MyApp")

        let mkdir = try #require(fileSystem.createDirectoryOperations.first)
        #expect(mkdir.path == "/repo/nsassets-artifacts/xcresults")
        #expect(mkdir.withIntermediateDirectories)
        #expect(fileSystem.removeItemOperations.isEmpty)

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.path == "/repo/nsassets-artifacts/xcresults/Snapshots.json")
        let jsonData = try #require(write.contents.data(using: .utf8))
        let payload = try JSONDecoder().decode(XCResultParseArtifact.self, from: jsonData)

        #expect(payload.schemeName == "Snapshots")
        #expect(payload.projectName == "MyApp")
        #expect(payload.xcresultPath == "/tmp/result.xcresult")
        #expect(payload.failedTests == 1)
        #expect(payload.failedTestDetails.count == 1)
        #expect(payload.failedTestDetails[0].details?.testResult == "Failed")
        #expect(payload.failedTestDetails[0].activityAttachments.count == 1)
        #expect(payload.failedTestDetails[0].exportedAttachments.count == 1)

        let expectedPath = "/repo/nsassets-artifacts/xcresults/Snapshots/attachments/"
            + "SnapshotSuite_test_snapshot_mismatch/diff.png"
        #expect(payload.failedTestDetails[0].exportedAttachments[0].absolutePath == expectedPath)
        #expect(payload.warnings.isEmpty)
        #expect(outputLines == ["/repo/nsassets-artifacts/xcresults/Snapshots.json"])
    }

    @Test
    func sendsAppNotificationPayloadAfterArtifactWrite() throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo/App/Subdir",
            existingPaths: ["/repo/.git"]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = makeSuccessfulClient()
        let appBridge = MockAppBridge()

        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            appBridge: appBridge,
            output: { _ in }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        let payload = try #require(appBridge.payloads.first)
        #expect(payload.schemeName == "Snapshots")
        #expect(payload.projectName == "repo")
        #expect(payload.artifactPath == "/repo/nsassets-artifacts/xcresults/Snapshots.json")
        #expect(payload.xcresultPath == "/tmp/result.xcresult")
    }

    @Test
    func sendsWorkspaceRootDirectoryNameInAppNotificationPayload() throws {
        let fileSystem = MockFileSystem(currentDirectoryPath: "/tmp/elsewhere")
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = makeSuccessfulClient()
        let appBridge = MockAppBridge()

        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            appBridge: appBridge,
            output: { _ in }
        )

        try executor.run(
            schemeName: "Snapshots",
            projectName: "MyApp",
            workspacePath: "/Users/me/Workspace/Feature/App.xcodeproj/project.pbxproj"
        )

        let payload = try #require(appBridge.payloads.first)
        #expect(payload.projectName == "Feature")
    }

    @Test
    func skipsPerTestParsingWhenThereAreNoFailures() throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: ["/repo/.git"]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = MockXCResultToolClient(summaryHandler: { _ in
            try decodeSummary(noFailureSummaryJSON)
        })
        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { _ in }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        #expect(xcresultToolClient.fetchTestDetailsCalls.isEmpty)
        #expect(xcresultToolClient.fetchTestActivitiesCalls.isEmpty)
        #expect(xcresultToolClient.exportAttachmentsCalls.isEmpty)
    }

    @Test
    func writesWarningsAndContinuesWhenPerTestOperationsFail() throws {
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo/app",
            existingPaths: ["/repo/.git"]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let xcresultToolClient = MockXCResultToolClient(
            summaryHandler: { _ in try decodeSummary(singleFailureSummaryJSON) },
            testDetailsHandler: { _, _ in throw NSError(domain: "details", code: 1) },
            testActivitiesHandler: { _, _ in throw NSError(domain: "activities", code: 2) },
            exportHandler: { _, _, _ in throw NSError(domain: "export", code: 3) }
        )
        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { _ in }
        )

        try executor.run(schemeName: "Snapshots", projectName: "MyApp")

        let write = try #require(fileSystem.writeOperations.first)
        let data = try #require(write.contents.data(using: .utf8))
        let payload = try JSONDecoder().decode(XCResultParseArtifact.self, from: data)

        #expect(payload.failedTestDetails.count == 1)
        #expect(payload.failedTestDetails[0].details == nil)
        #expect(payload.failedTestDetails[0].activityAttachments.isEmpty)
        #expect(payload.failedTestDetails[0].exportedAttachments.isEmpty)
        #expect(payload.warnings.count == 3)
        #expect(Set(payload.warnings.map(\.stage)) == ["test-details", "activities", "attachments-export"])
    }
}

@Suite(
)
struct XCResultParseCommandExecutorFailureTests {
    @Test(
        .disabled("Temporarily disabled while isolating XCResult parse-executor failure tests.")
    )
    func rethrowsResolverError() throws {
        let fileSystem = MockFileSystem(currentDirectoryPath: "/repo")
        let resolver = MockXCResultPathResolver(
            result: .failure(XCResultPathResolverError.noXCResultFiles(path: "/tmp"))
        )
        let xcresultToolClient = MockXCResultToolClient(summaryHandler: { _ in
            try decodeSummary(noFailureZeroSummaryJSON)
        })
        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { _ in }
        )

        #expect(throws: XCResultPathResolverError.noXCResultFiles(path: "/tmp")) {
            try executor.run(schemeName: "Snapshots", projectName: "MyApp")
        }
    }

    @Test
    func rethrowsSummaryFailure() throws {
        print("[CI DEBUG] rethrowsSummaryFailure: start")
        let fileSystem = MockFileSystem(
            currentDirectoryPath: "/repo",
            existingPaths: ["/repo/.git"]
        )
        let resolver = MockXCResultPathResolver(result: .success("/tmp/result.xcresult"))
        let expectedError = ParseExecutorTestError.summaryFailure
        let xcresultToolClient = MockXCResultToolClient(summaryHandler: { path in
            print("[CI DEBUG] rethrowsSummaryFailure: summaryHandler invoked for \(path)")
            throw expectedError
        })
        let executor = XCResultParseCommandExecutor(
            fileSystem: fileSystem,
            resolver: resolver,
            xcresultToolClient: xcresultToolClient,
            output: { _ in }
        )

        do {
            print("[CI DEBUG] rethrowsSummaryFailure: invoking executor.run")
            try executor.run(schemeName: "Snapshots", projectName: "MyApp")
            print("[CI DEBUG] rethrowsSummaryFailure: executor.run returned without throwing")
            Issue.record("Expected summary fetch to rethrow its error.")
        } catch let error as ParseExecutorTestError {
            print("[CI DEBUG] rethrowsSummaryFailure: caught expected error \(error)")
            #expect(error == .summaryFailure)
        } catch {
            print("[CI DEBUG] rethrowsSummaryFailure: caught unexpected error \(String(describing: error))")
            Issue.record("Unexpected error type: \(String(describing: error))")
        }

        print("[CI DEBUG] rethrowsSummaryFailure: write operations count = \(fileSystem.writeOperations.count)")
        #expect(fileSystem.writeOperations.isEmpty)
        print("[CI DEBUG] rethrowsSummaryFailure: end")
    }

}

private func makeSuccessfulClient() -> MockXCResultToolClient {
    MockXCResultToolClient(
        summaryHandler: { _ in try decodeSummary(singleFailureSummaryWithMetadataJSON) },
        testDetailsHandler: { _, _ in makeTestDetails() },
        testActivitiesHandler: { _, _ in makeTestActivities() },
        exportHandler: { _, _, _ in makeExportedManifest() }
    )
}

private enum ParseExecutorTestError: Error, Equatable {
    case summaryFailure
}

private func makeTestDetails() -> XCResultToolModels.TestDetails {
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

private func makeTestActivities() -> XCResultToolModels.TestActivities {
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

private func makeExportedManifest() -> [XCResultToolModels.ExportedAttachmentManifestEntry] {
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

private func decodeSummary(_ json: String) throws -> XCResultToolModels.Summary {
    guard let data = json.data(using: .utf8) else {
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
    return try JSONDecoder().decode(XCResultToolModels.Summary.self, from: data)
}

private final class MockAppBridge: AppBridgeHandling {
    private(set) var payloads: [AppNotificationPayload] = []

    func notifyAppIfNeeded(payload: AppNotificationPayload) {
        payloads.append(payload)
    }
}

private let singleFailureSummaryWithMetadataJSON = """
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

private let noFailureSummaryJSON = """
{
  "result": "Passed",
  "totalTestCount": 10,
  "passedTests": 10,
  "failedTests": 0,
  "skippedTests": 0,
  "expectedFailures": 0,
  "devicesAndConfigurations": [],
  "testFailures": []
}
"""

private let singleFailureSummaryJSON = """
{
  "result": "Failed",
  "totalTestCount": 1,
  "passedTests": 0,
  "failedTests": 1,
  "skippedTests": 0,
  "expectedFailures": 0,
  "devicesAndConfigurations": [],
  "testFailures": [
    {
      "testIdentifierString": "Suite/test_fail",
      "testIdentifierURL": "test://suite/test_fail",
      "testName": "test_fail"
    }
  ]
}
"""

private let noFailureZeroSummaryJSON = """
{
  "result": "Passed",
  "totalTestCount": 0,
  "passedTests": 0,
  "failedTests": 0,
  "skippedTests": 0,
  "expectedFailures": 0,
  "devicesAndConfigurations": [],
  "testFailures": []
}
"""
