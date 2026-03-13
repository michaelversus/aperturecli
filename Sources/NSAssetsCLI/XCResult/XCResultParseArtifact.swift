import Foundation

struct XCResultParseArtifact: Codable {
    let schemeName: String
    let projectName: String
    let xcresultPath: String
    let title: String?
    let environmentDescription: String?
    let result: String
    let startTime: Double?
    let finishTime: Double?
    let totalTestCount: Int
    let passedTests: Int
    let failedTests: Int
    let skippedTests: Int
    let expectedFailures: Int
    let devicesAndConfigurations: [XCResultToolModels.DeviceAndConfiguration]
    let failedTestDetails: [FailedTest]
    let warnings: [Warning]

    struct FailedTest: Codable {
        let identifier: String?
        let identifierURL: String?
        let name: String?
        let targetName: String?
        let failureText: String?
        let details: Details?
        let activityAttachments: [ActivityAttachment]
        let exportedAttachments: [ExportedAttachment]
    }

    struct Details: Codable {
        let duration: String?
        let durationInSeconds: Double?
        let hasMediaAttachments: Bool?
        let hasPerformanceMetrics: Bool?
        let startTime: Double?
        let testDescription: String?
        let testResult: String?
    }

    struct ActivityAttachment: Codable {
        let name: String?
        let payloadId: String?
        let uuid: String?
        let lifetime: String?
        let timestamp: Double?
    }

    struct ExportedAttachment: Codable {
        let exportedFileName: String
        let suggestedHumanReadableName: String
        let absolutePath: String
        let isAssociatedWithFailure: Bool
        let timestamp: Double?
        let configurationName: String?
        let deviceName: String?
        let deviceId: String?
        let repetitionNumber: Int?
        let arguments: [Int]?
    }

    struct Warning: Codable {
        let stage: String
        let testIdentifier: String?
        let message: String
    }
}
