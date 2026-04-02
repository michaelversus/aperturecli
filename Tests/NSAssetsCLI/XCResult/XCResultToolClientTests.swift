import Foundation
import Testing
@testable import NSAssetsCLI

struct XCResultToolClientTests {
    @Test
    func fetchSummaryBuildsExpectedCommandAndDecodesPayload() throws {
        let runner = MockCommandRunner(
            queuedResults: [
                .success(
                    """
                    {
                      "result": "Passed",
                      "totalTestCount": 1,
                      "passedTests": 1,
                      "failedTests": 0,
                      "skippedTests": 0,
                      "expectedFailures": 0,
                      "devicesAndConfigurations": [],
                      "testFailures": []
                    }
                    """
                )
            ]
        )
        let fileSystem = MockFileSystem()
        let sleepRecorder = SleepRecorder()
        let sut = makeSUT(runner: runner, fileSystem: fileSystem, sleepRecorder: sleepRecorder)

        let summary = try sut.fetchSummary(xcresultPath: "/tmp/run.xcresult")

        #expect(summary.result == "Passed")
        #expect(summary.totalTestCount == 1)
        #expect(sleepRecorder.intervals == [2.0])
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.executable == "/usr/bin/xcrun")
        #expect(
            invocation.arguments
                == ["xcresulttool", "get", "test-results", "summary", "--path", "/tmp/run.xcresult"]
        )
    }

    @Test
    func fetchSummaryRetriesOnTransientXCResultReadinessError() throws {
        let transientError = SubprocessRunnerError.commandFailed(
            executable: "/usr/bin/xcrun",
            arguments: ["xcresulttool", "get", "test-results", "summary"],
            exitCode: 64,
            output: """
            Error: Failed to create a new result bundle reader, underlying error: \
            Info.plist at /tmp/Test.xcresult/Info.plist does not exist, \
            the result bundle might be corrupted
            """
        )
        let runner = MockCommandRunner(
            queuedResults: [
                .failure(transientError),
                .success(
                    """
                    {
                      "result": "Passed",
                      "totalTestCount": 1,
                      "passedTests": 1,
                      "failedTests": 0,
                      "skippedTests": 0,
                      "expectedFailures": 0,
                      "devicesAndConfigurations": [],
                      "testFailures": []
                    }
                    """
                )
            ]
        )
        let sleepRecorder = SleepRecorder()
        let sut = makeSUT(runner: runner, fileSystem: MockFileSystem(), sleepRecorder: sleepRecorder)

        let summary = try sut.fetchSummary(xcresultPath: "/tmp/run.xcresult")

        #expect(summary.result == "Passed")
        #expect(runner.invocations.count == 2)
        #expect(sleepRecorder.intervals == [2.0, 0.25])
    }

    @Test
    func fetchSummaryRetriesMultipleTransientReadinessErrors() throws {
        let transientError = SubprocessRunnerError.commandFailed(
            executable: "/usr/bin/xcrun",
            arguments: ["xcresulttool", "get", "test-results", "summary"],
            exitCode: 64,
            output: """
            Error: Failed to create a new result bundle reader, underlying error: \
            Info.plist at /tmp/Test.xcresult/Info.plist does not exist, \
            the result bundle might be corrupted
            """
        )
        let runner = MockCommandRunner(
            queuedResults: [
                .failure(transientError),
                .failure(transientError),
                .failure(transientError),
                .success(
                    """
                    {
                      "result": "Passed",
                      "totalTestCount": 1,
                      "passedTests": 1,
                      "failedTests": 0,
                      "skippedTests": 0,
                      "expectedFailures": 0,
                      "devicesAndConfigurations": [],
                      "testFailures": []
                    }
                    """
                )
            ]
        )
        let sleepRecorder = SleepRecorder()
        let sut = makeSUT(runner: runner, fileSystem: MockFileSystem(), sleepRecorder: sleepRecorder)

        let summary = try sut.fetchSummary(xcresultPath: "/tmp/run.xcresult")

        #expect(summary.result == "Passed")
        #expect(runner.invocations.count == 4)
        #expect(sleepRecorder.intervals == [2.0, 0.25, 0.5, 1.0])
    }

    @Test
    func fetchSummaryDoesNotRetryOnNonTransientError() throws {
        let nonTransientError = SubprocessRunnerError.commandFailed(
            executable: "/usr/bin/xcrun",
            arguments: ["xcresulttool", "get", "test-results", "summary"],
            exitCode: 64,
            output: "Error: bad invocation"
        )
        let runner = MockCommandRunner(queuedResults: [.failure(nonTransientError)])
        let sleepRecorder = SleepRecorder()
        let sut = makeSUT(runner: runner, fileSystem: MockFileSystem(), sleepRecorder: sleepRecorder)

        #expect(throws: SubprocessRunnerError.commandFailed(
            executable: "/usr/bin/xcrun",
            arguments: ["xcresulttool", "get", "test-results", "summary"],
            exitCode: 64,
            output: "Error: bad invocation"
        )) {
            try sut.fetchSummary(xcresultPath: "/tmp/run.xcresult")
        }
        #expect(runner.invocations.count == 1)
        #expect(sleepRecorder.intervals == [2.0])
    }

    @Test
    func fetchTestDetailsAndActivitiesBuildExpectedCommands() throws {
        let runner = MockCommandRunner(
            queuedResults: [
                .success(
                    """
                    {
                      "duration": "1s",
                      "testIdentifier": "Suite/testName"
                    }
                    """
                ),
                .success(
                    """
                    {
                      "testIdentifier": "Suite/testName",
                      "testRuns": []
                    }
                    """
                )
            ]
        )
        let fileSystem = MockFileSystem()
        let sleepRecorder = SleepRecorder()
        let sut = makeSUT(runner: runner, fileSystem: fileSystem, sleepRecorder: sleepRecorder)

        _ = try sut.fetchTestDetails(xcresultPath: "/tmp/run.xcresult", testIdentifier: "Suite/testName")
        _ = try sut.fetchTestActivities(xcresultPath: "/tmp/run.xcresult", testIdentifier: "Suite/testName")

        #expect(runner.invocations.count == 2)
        #expect(sleepRecorder.intervals.isEmpty)
        #expect(
            runner.invocations[0].arguments
                == [
                    "xcresulttool", "get", "test-results", "test-details",
                    "--path", "/tmp/run.xcresult",
                    "--test-id", "Suite/testName"
                ]
        )
        #expect(
            runner.invocations[1].arguments
                == [
                    "xcresulttool", "get", "test-results", "activities",
                    "--path", "/tmp/run.xcresult",
                    "--test-id", "Suite/testName"
                ]
        )
    }

    @Test
    func exportAttachmentsDecodesManifestWithOptionalFields() throws {
        let runner = MockCommandRunner(queuedResults: [.success("ok")])
        let outputPath = "/tmp/export"
        let manifestPath = "/tmp/export/manifest.json"
        let fileSystem = MockFileSystem(
            fileExistsResults: [manifestPath: true],
            fileContentsByPath: [manifestPath: exportedAttachmentsManifestJSON]
        )
        let sleepRecorder = SleepRecorder()
        let sut = makeSUT(runner: runner, fileSystem: fileSystem, sleepRecorder: sleepRecorder)

        let manifest = try sut.exportAttachments(
            xcresultPath: "/tmp/run.xcresult",
            testIdentifier: "Suite/testName",
            outputPath: outputPath
        )

        #expect(manifest.count == 1)
        #expect(manifest[0].attachments.count == 2)
        #expect(manifest[0].attachments[0].timestamp == 1.1)
        #expect(manifest[0].attachments[1].timestamp == nil)
        #expect(sleepRecorder.intervals.isEmpty)
        let invocation = try #require(runner.invocations.first)
        #expect(
            invocation.arguments
                == [
                    "xcresulttool", "export", "attachments",
                    "--path", "/tmp/run.xcresult",
                    "--test-id", "Suite/testName",
                    "--output-path", outputPath
                ]
        )
    }

    @Test
    func exportAttachmentsThrowsWhenManifestIsMissing() throws {
        let runner = MockCommandRunner(queuedResults: [.success("ok")])
        let fileSystem = MockFileSystem(fileExistsResults: [:])
        let sleepRecorder = SleepRecorder()
        let sut = makeSUT(runner: runner, fileSystem: fileSystem, sleepRecorder: sleepRecorder)

        #expect(throws: XCResultToolClientError.missingManifest(path: "/tmp/export/manifest.json")) {
            try sut.exportAttachments(
                xcresultPath: "/tmp/run.xcresult",
                testIdentifier: "Suite/testName",
                outputPath: "/tmp/export"
            )
        }
        #expect(sleepRecorder.intervals.isEmpty)
    }
}

private func makeSUT(
    runner: MockCommandRunner,
    fileSystem: FileSystemProvider,
    sleepRecorder: SleepRecorder
) -> XCResultToolClient {
    XCResultToolClient(
        commandRunner: runner,
        fileSystem: fileSystem,
        sleep: { interval in
            sleepRecorder.intervals.append(interval)
        }
    )
}

private final class SleepRecorder {
    var intervals: [TimeInterval] = []
}

private let exportedAttachmentsManifestJSON =
    """
    [
      {
        "testIdentifier": "Suite/testName",
        "testIdentifierURL": "test://suite/testName",
        "attachments": [
          {
            "exportedFileName": "one.png",
            "suggestedHumanReadableName": "reference.png",
            "isAssociatedWithFailure": false,
            "timestamp": 1.1
          },
          {
            "exportedFileName": "two.txt",
            "suggestedHumanReadableName": "issue.txt",
            "isAssociatedWithFailure": true
          }
        ]
      }
    ]
    """
