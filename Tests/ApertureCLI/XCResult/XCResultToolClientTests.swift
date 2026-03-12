import Foundation
import Testing
@testable import ApertureCLI

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
        let sut = XCResultToolClient(commandRunner: runner, fileSystem: fileSystem)

        let summary = try sut.fetchSummary(xcresultPath: "/tmp/run.xcresult")

        #expect(summary.result == "Passed")
        #expect(summary.totalTestCount == 1)
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.executable == "/usr/bin/xcrun")
        #expect(
            invocation.arguments
                == ["xcresulttool", "get", "test-results", "summary", "--path", "/tmp/run.xcresult"]
        )
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
        let sut = XCResultToolClient(commandRunner: runner, fileSystem: fileSystem)

        _ = try sut.fetchTestDetails(xcresultPath: "/tmp/run.xcresult", testIdentifier: "Suite/testName")
        _ = try sut.fetchTestActivities(xcresultPath: "/tmp/run.xcresult", testIdentifier: "Suite/testName")

        #expect(runner.invocations.count == 2)
        #expect(
            runner.invocations[0].arguments
                == [
                    "xcresulttool", "get", "test-results", "test-details",
                    "--path", "/tmp/run.xcresult",
                    "--test-id", "Suite/testName",
                ]
        )
        #expect(
            runner.invocations[1].arguments
                == [
                    "xcresulttool", "get", "test-results", "activities",
                    "--path", "/tmp/run.xcresult",
                    "--test-id", "Suite/testName",
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
            fileContentsByPath: [
                manifestPath:
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
            ]
        )
        let sut = XCResultToolClient(commandRunner: runner, fileSystem: fileSystem)

        let manifest = try sut.exportAttachments(
            xcresultPath: "/tmp/run.xcresult",
            testIdentifier: "Suite/testName",
            outputPath: outputPath
        )

        #expect(manifest.count == 1)
        #expect(manifest[0].attachments.count == 2)
        #expect(manifest[0].attachments[0].timestamp == 1.1)
        #expect(manifest[0].attachments[1].timestamp == nil)
        let invocation = try #require(runner.invocations.first)
        #expect(
            invocation.arguments
                == [
                    "xcresulttool", "export", "attachments",
                    "--path", "/tmp/run.xcresult",
                    "--test-id", "Suite/testName",
                    "--output-path", outputPath,
                ]
        )
    }

    @Test
    func exportAttachmentsThrowsWhenManifestIsMissing() throws {
        let runner = MockCommandRunner(queuedResults: [.success("ok")])
        let fileSystem = MockFileSystem(fileExistsResults: [:])
        let sut = XCResultToolClient(commandRunner: runner, fileSystem: fileSystem)

        #expect(throws: XCResultToolClientError.missingManifest(path: "/tmp/export/manifest.json")) {
            try sut.exportAttachments(
                xcresultPath: "/tmp/run.xcresult",
                testIdentifier: "Suite/testName",
                outputPath: "/tmp/export"
            )
        }
    }
}

