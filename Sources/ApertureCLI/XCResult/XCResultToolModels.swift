import Foundation

enum XCResultToolModels {
    struct Summary: Decodable {
        let title: String?
        let startTime: Double?
        let finishTime: Double?
        let environmentDescription: String?
        let result: String
        let totalTestCount: Int
        let passedTests: Int
        let failedTests: Int
        let skippedTests: Int
        let expectedFailures: Int
        let devicesAndConfigurations: [DeviceAndConfiguration]
        let testFailures: [TestFailure]

        private enum CodingKeys: String, CodingKey {
            case title
            case startTime
            case finishTime
            case environmentDescription
            case result
            case totalTestCount
            case passedTests
            case failedTests
            case skippedTests
            case expectedFailures
            case devicesAndConfigurations
            case testFailures
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            startTime = try container.decodeIfPresent(Double.self, forKey: .startTime)
            finishTime = try container.decodeIfPresent(Double.self, forKey: .finishTime)
            environmentDescription = try container.decodeIfPresent(String.self, forKey: .environmentDescription)
            result = try container.decodeIfPresent(String.self, forKey: .result) ?? "unknown"
            totalTestCount = try container.decodeIfPresent(Int.self, forKey: .totalTestCount) ?? 0
            passedTests = try container.decodeIfPresent(Int.self, forKey: .passedTests) ?? 0
            failedTests = try container.decodeIfPresent(Int.self, forKey: .failedTests) ?? 0
            skippedTests = try container.decodeIfPresent(Int.self, forKey: .skippedTests) ?? 0
            expectedFailures = try container.decodeIfPresent(Int.self, forKey: .expectedFailures) ?? 0
            devicesAndConfigurations = try container.decodeIfPresent(
                [DeviceAndConfiguration].self,
                forKey: .devicesAndConfigurations
            ) ?? []
            testFailures = try container.decodeIfPresent([TestFailure].self, forKey: .testFailures) ?? []
        }
    }

    struct DeviceAndConfiguration: Codable, Equatable {
        let device: Device?
        let testPlanConfiguration: TestPlanConfiguration?
        let expectedFailures: Int?
        let failedTests: Int?
        let passedTests: Int?
        let skippedTests: Int?
    }

    struct Device: Codable, Equatable {
        let deviceId: String?
        let deviceName: String?
        let architecture: String?
        let modelName: String?
        let platform: String?
        let osVersion: String?
        let osBuildNumber: String?
    }

    struct TestPlanConfiguration: Codable, Equatable {
        let configurationId: String?
        let configurationName: String?
    }

    struct TestFailure: Codable, Equatable {
        let failureText: String?
        let targetName: String?
        let testIdentifier: Int?
        let testIdentifierString: String?
        let testIdentifierURL: String?
        let testName: String?
    }

    struct TestDetails: Decodable {
        let duration: String?
        let durationInSeconds: Double?
        let hasMediaAttachments: Bool?
        let hasPerformanceMetrics: Bool?
        let startTime: Double?
        let testDescription: String?
        let testIdentifier: String?
        let testIdentifierURL: String?
        let testName: String?
        let testResult: String?
    }

    struct TestActivities: Decodable {
        let testIdentifier: String?
        let testIdentifierURL: String?
        let testName: String?
        let testRuns: [ActivityTestRun]
    }

    struct ActivityTestRun: Decodable {
        let activities: [Activity]
    }

    struct Activity: Decodable {
        let attachments: [ActivityAttachment]?
        let childActivities: [Activity]?
        let title: String?
        let isAssociatedWithFailure: Bool?
    }

    struct ActivityAttachment: Decodable {
        let lifetime: String?
        let name: String?
        let payloadId: String?
        let timestamp: Double?
        let uuid: String?
    }

    struct ExportedAttachmentManifestEntry: Decodable {
        let testIdentifier: String
        let testIdentifierURL: String?
        let attachments: [ExportedAttachment]
    }

    struct ExportedAttachment: Codable, Equatable {
        let exportedFileName: String
        let suggestedHumanReadableName: String
        let isAssociatedWithFailure: Bool
        let timestamp: Double?
        let configurationName: String?
        let deviceName: String?
        let deviceId: String?
        let repetitionNumber: Int?
        let arguments: [Int]?
    }
}

