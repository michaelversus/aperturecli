import Foundation

extension XCResultParseCommandExecutor {
    func prepareArtifactDirectories(
        schemeName: String,
        workspacePath: String?
    ) throws -> ArtifactDirectories {
        let resolvedRepoRoot = resolveRepoRoot(workspacePath: workspacePath)
        let artifactsDirectory = URL(fileURLWithPath: resolvedRepoRoot, isDirectory: true)
            .appendingPathComponent("nsassets-artifacts", isDirectory: true)
            .appendingPathComponent("xcresults", isDirectory: true)
        try fileSystem.createDirectory(atPath: artifactsDirectory.path, withIntermediateDirectories: true)

        let schemeAttachmentsDirectory = artifactsDirectory
            .appendingPathComponent(sanitizePathComponent(schemeName), isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
        if fileSystem.fileExists(atPath: schemeAttachmentsDirectory.path) {
            try fileSystem.removeItem(atPath: schemeAttachmentsDirectory.path)
        }
        try fileSystem.createDirectory(
            atPath: schemeAttachmentsDirectory.path,
            withIntermediateDirectories: true
        )

        return ArtifactDirectories(
            artifactPath: artifactsDirectory.appendingPathComponent("\(schemeName).json").path,
            schemeAttachmentsDirectory: schemeAttachmentsDirectory
        )
    }

    func parseFailedTests(
        testFailures: [XCResultToolModels.TestFailure],
        xcresultPath: String,
        schemeAttachmentsDirectory: URL
    ) throws -> (failedTests: [XCResultParseArtifact.FailedTest], warnings: [XCResultParseArtifact.Warning]) {
        var failedTestDetails: [XCResultParseArtifact.FailedTest] = []
        var warnings: [XCResultParseArtifact.Warning] = []

        for testFailure in testFailures {
            let result = try parseSingleFailedTest(
                testFailure,
                xcresultPath: xcresultPath,
                schemeAttachmentsDirectory: schemeAttachmentsDirectory
            )
            failedTestDetails.append(result.failedTest)
            warnings.append(contentsOf: result.warnings)
        }

        return (failedTestDetails, warnings)
    }

    func parseSingleFailedTest(
        _ testFailure: XCResultToolModels.TestFailure,
        xcresultPath: String,
        schemeAttachmentsDirectory: URL
    ) throws -> (failedTest: XCResultParseArtifact.FailedTest, warnings: [XCResultParseArtifact.Warning]) {
        var warnings: [XCResultParseArtifact.Warning] = []
        var details: XCResultParseArtifact.Details?
        var activityAttachments: [XCResultParseArtifact.ActivityAttachment] = []
        var exportedAttachments: [XCResultParseArtifact.ExportedAttachment] = []

        guard let testIdentifier = resolvedTestIdentifier(from: testFailure) else {
            warnings.append(
                XCResultParseArtifact.Warning(
                    stage: "identifier-resolution",
                    testIdentifier: nil,
                    message: "Missing test identifier in xcresult test failure entry."
                )
            )
            let failedTest = buildFailedTest(
                from: testFailure,
                details: nil,
                activityAttachments: [],
                exportedAttachments: []
            )
            return (failedTest, warnings)
        }

        details = fetchTestDetailsSafely(
            xcresultPath: xcresultPath,
            testIdentifier: testIdentifier,
            warnings: &warnings
        )
        activityAttachments = fetchActivitiesSafely(
            xcresultPath: xcresultPath,
            testIdentifier: testIdentifier,
            warnings: &warnings
        )
        exportedAttachments = try exportAttachmentsSafely(
            testFailure: testFailure,
            xcresultPath: xcresultPath,
            testIdentifier: testIdentifier,
            schemeAttachmentsDirectory: schemeAttachmentsDirectory,
            warnings: &warnings
        )

        let failedTest = buildFailedTest(
            from: testFailure,
            details: details,
            activityAttachments: activityAttachments,
            exportedAttachments: exportedAttachments
        )
        return (failedTest, warnings)
    }

    func buildFailedTest(
        from testFailure: XCResultToolModels.TestFailure,
        details: XCResultParseArtifact.Details?,
        activityAttachments: [XCResultParseArtifact.ActivityAttachment],
        exportedAttachments: [XCResultParseArtifact.ExportedAttachment]
    ) -> XCResultParseArtifact.FailedTest {
        XCResultParseArtifact.FailedTest(
            identifier: testFailure.testIdentifierString,
            identifierURL: testFailure.testIdentifierURL,
            name: testFailure.testName,
            targetName: testFailure.targetName,
            failureText: testFailure.failureText,
            details: details,
            activityAttachments: activityAttachments,
            exportedAttachments: exportedAttachments
        )
    }

    func fetchTestDetailsSafely(
        xcresultPath: String,
        testIdentifier: String,
        warnings: inout [XCResultParseArtifact.Warning]
    ) -> XCResultParseArtifact.Details? {
        do {
            let testDetails = try xcresultToolClient.fetchTestDetails(
                xcresultPath: xcresultPath,
                testIdentifier: testIdentifier
            )
            return XCResultParseArtifact.Details(
                duration: testDetails.duration,
                durationInSeconds: testDetails.durationInSeconds,
                hasMediaAttachments: testDetails.hasMediaAttachments,
                hasPerformanceMetrics: testDetails.hasPerformanceMetrics,
                startTime: testDetails.startTime,
                testDescription: testDetails.testDescription,
                testResult: testDetails.testResult
            )
        } catch {
            warnings.append(
                XCResultParseArtifact.Warning(
                    stage: "test-details",
                    testIdentifier: testIdentifier,
                    message: error.localizedDescription
                )
            )
            return nil
        }
    }

    func fetchActivitiesSafely(
        xcresultPath: String,
        testIdentifier: String,
        warnings: inout [XCResultParseArtifact.Warning]
    ) -> [XCResultParseArtifact.ActivityAttachment] {
        do {
            let testActivities = try xcresultToolClient.fetchTestActivities(
                xcresultPath: xcresultPath,
                testIdentifier: testIdentifier
            )
            return flattenActivityAttachments(from: testActivities)
        } catch {
            warnings.append(
                XCResultParseArtifact.Warning(
                    stage: "activities",
                    testIdentifier: testIdentifier,
                    message: error.localizedDescription
                )
            )
            return []
        }
    }

    func exportAttachmentsSafely(
        testFailure: XCResultToolModels.TestFailure,
        xcresultPath: String,
        testIdentifier: String,
        schemeAttachmentsDirectory: URL,
        warnings: inout [XCResultParseArtifact.Warning]
    ) throws -> [XCResultParseArtifact.ExportedAttachment] {
        let safeTestID = sanitizePathComponent(testIdentifier)
        let testAttachmentsDirectory = schemeAttachmentsDirectory
            .appendingPathComponent(safeTestID, isDirectory: true)
        do {
            try fileSystem.createDirectory(
                atPath: testAttachmentsDirectory.path,
                withIntermediateDirectories: true
            )
            let manifest = try xcresultToolClient.exportAttachments(
                xcresultPath: xcresultPath,
                testIdentifier: testIdentifier,
                outputPath: testAttachmentsDirectory.path
            )
            let manifestEntry = manifest.first {
                $0.testIdentifier == testIdentifier || $0.testIdentifierURL == testFailure.testIdentifierURL
            } ?? manifest.first
            return (manifestEntry?.attachments ?? []).map { exported in
                XCResultParseArtifact.ExportedAttachment(
                    exportedFileName: exported.exportedFileName,
                    suggestedHumanReadableName: exported.suggestedHumanReadableName,
                    absolutePath: testAttachmentsDirectory
                        .appendingPathComponent(exported.exportedFileName, isDirectory: false)
                        .path,
                    isAssociatedWithFailure: exported.isAssociatedWithFailure,
                    timestamp: exported.timestamp,
                    configurationName: exported.configurationName,
                    deviceName: exported.deviceName,
                    deviceId: exported.deviceId,
                    repetitionNumber: exported.repetitionNumber,
                    arguments: exported.arguments
                )
            }
        } catch {
            warnings.append(
                XCResultParseArtifact.Warning(
                    stage: "attachments-export",
                    testIdentifier: testIdentifier,
                    message: error.localizedDescription
                )
            )
            return []
        }
    }

    func resolvedTestIdentifier(from failure: XCResultToolModels.TestFailure) -> String? {
        if let identifier = failure.testIdentifierString?.trimmingCharacters(in: .whitespacesAndNewlines),
           !identifier.isEmpty {
            return identifier
        }
        if let identifierURL = failure.testIdentifierURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !identifierURL.isEmpty {
            return identifierURL
        }
        return nil
    }

    func sanitizePathComponent(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "_",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    func flattenActivityAttachments(
        from activities: XCResultToolModels.TestActivities
    ) -> [XCResultParseArtifact.ActivityAttachment] {
        var flattened: [XCResultParseArtifact.ActivityAttachment] = []
        for run in activities.testRuns {
            for activity in run.activities {
                flatten(activity: activity, into: &flattened)
            }
        }
        return flattened
    }

    func flatten(
        activity: XCResultToolModels.Activity,
        into attachments: inout [XCResultParseArtifact.ActivityAttachment]
    ) {
        for attachment in activity.attachments ?? [] {
            attachments.append(
                XCResultParseArtifact.ActivityAttachment(
                    name: attachment.name,
                    payloadId: attachment.payloadId,
                    uuid: attachment.uuid,
                    lifetime: attachment.lifetime,
                    timestamp: attachment.timestamp
                )
            )
        }

        for child in activity.childActivities ?? [] {
            flatten(activity: child, into: &attachments)
        }
    }
}
