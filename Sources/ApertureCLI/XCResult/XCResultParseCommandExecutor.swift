import Foundation

struct XCResultParseCommandExecutor {
    let fileSystem: FileSystemProvider
    let resolver: XCResultPathResolving
    let xcresultToolClient: XCResultToolProviding
    let output: (String) -> Void

    func run(schemeName: String, projectName: String, workspacePath: String? = nil) throws {
        let xcresultPath = try resolver.resolvePath(
            schemeName: schemeName,
            projectName: projectName
        )
        let summary = try xcresultToolClient.fetchSummary(xcresultPath: xcresultPath)

        let resolvedRepoRoot = resolveRepoRoot(workspacePath: workspacePath)
        let artifactsDirectory = URL(fileURLWithPath: resolvedRepoRoot, isDirectory: true)
            .appendingPathComponent("aperture-artifacts", isDirectory: true)
            .appendingPathComponent("xcresults", isDirectory: true)
        try fileSystem.createDirectory(
            atPath: artifactsDirectory.path,
            withIntermediateDirectories: true
        )

        let artifactPath = artifactsDirectory
            .appendingPathComponent("\(schemeName).json", isDirectory: false)
            .path

        let schemeAttachmentsDirectory = artifactsDirectory
            .appendingPathComponent(sanitizePathComponent(schemeName), isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
        try fileSystem.createDirectory(
            atPath: schemeAttachmentsDirectory.path,
            withIntermediateDirectories: true
        )

        var failedTestDetails: [XCResultParseArtifact.FailedTest] = []
        var warnings: [XCResultParseArtifact.Warning] = []

        for testFailure in summary.testFailures {
            var details: XCResultParseArtifact.Details?
            var activityAttachments: [XCResultParseArtifact.ActivityAttachment] = []
            var exportedAttachments: [XCResultParseArtifact.ExportedAttachment] = []

            let testIdentifier = resolvedTestIdentifier(from: testFailure)

            if let testIdentifier {
                do {
                    let testDetails = try xcresultToolClient.fetchTestDetails(
                        xcresultPath: xcresultPath,
                        testIdentifier: testIdentifier
                    )
                    details = XCResultParseArtifact.Details(
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
                }

                do {
                    let testActivities = try xcresultToolClient.fetchTestActivities(
                        xcresultPath: xcresultPath,
                        testIdentifier: testIdentifier
                    )
                    activityAttachments = flattenActivityAttachments(from: testActivities)
                } catch {
                    warnings.append(
                        XCResultParseArtifact.Warning(
                            stage: "activities",
                            testIdentifier: testIdentifier,
                            message: error.localizedDescription
                        )
                    )
                }

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
                        $0.testIdentifier == testIdentifier
                            || $0.testIdentifierURL == testFailure.testIdentifierURL
                    } ?? manifest.first
                    exportedAttachments = (manifestEntry?.attachments ?? []).map { exported in
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
                }
            } else {
                warnings.append(
                    XCResultParseArtifact.Warning(
                        stage: "identifier-resolution",
                        testIdentifier: nil,
                        message: "Missing test identifier in xcresult test failure entry."
                    )
                )
            }

            failedTestDetails.append(
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
            )
        }

        let payload = XCResultParseArtifact(
            schemeName: schemeName,
            projectName: projectName,
            xcresultPath: xcresultPath,
            title: summary.title,
            environmentDescription: summary.environmentDescription,
            result: summary.result,
            startTime: summary.startTime,
            finishTime: summary.finishTime,
            totalTestCount: summary.totalTestCount,
            passedTests: summary.passedTests,
            failedTests: summary.failedTests,
            skippedTests: summary.skippedTests,
            expectedFailures: summary.expectedFailures,
            devicesAndConfigurations: summary.devicesAndConfigurations,
            failedTestDetails: failedTestDetails,
            warnings: warnings
        )

        let data = try JSONEncoder.prettySorted.encode(payload)
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try fileSystem.writeFile(json + "\n", toPath: artifactPath)

        output(artifactPath)
    }

    private func resolveRepoRoot(workspacePath: String?) -> String {
        if let workspacePath {
            let trimmed = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return repoRoot(fromWorkspacePath: trimmed)
            }
        }

        return resolveRepoRoot(startingAt: fileSystem.currentDirectoryPath())
    }

    private func repoRoot(fromWorkspacePath workspacePath: String) -> String {
        let workspaceURL = URL(fileURLWithPath: workspacePath).standardizedFileURL
        let workspaceDirectoryURL = workspaceURL.deletingLastPathComponent()

        if workspaceDirectoryURL.pathExtension == "xcodeproj" {
            return workspaceDirectoryURL.deletingLastPathComponent().path
        }

        return workspaceDirectoryURL.path
    }

    private func resolveRepoRoot(startingAt path: String) -> String {
        var current = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        while true {
            let gitPath = URL(fileURLWithPath: current, isDirectory: true)
                .appendingPathComponent(".git", isDirectory: true)
                .path
            if fileSystem.fileExists(atPath: gitPath) {
                return current
            }

            let parent = URL(fileURLWithPath: current, isDirectory: true)
                .deletingLastPathComponent()
                .path
            if parent == current || parent.isEmpty {
                return path
            }
            current = parent
        }
    }

    private func resolvedTestIdentifier(from failure: XCResultToolModels.TestFailure) -> String? {
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

    private func sanitizePathComponent(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "_",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    private func flattenActivityAttachments(
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

    private func flatten(
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

private extension JSONEncoder {
    static var prettySorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
