import Foundation

struct ApertureConfig: Codable, Sendable {
    let repoRoot: String
    let iosVersion: String
    let simulatorModel: String
    let xcodeVersion: String
    let projectFileName: String
    let spmPackagesContainerPath: String
    let snapshotTestSchemes: [String]

    enum CodingKeys: String, CodingKey {
        case repoRoot
        case iosVersion
        case simulatorModel
        case xcodeVersion
        case projectFileName
        case spmPackagesContainerPath
        case snapshotTestSchemes
    }

    init(
        repoRoot: String,
        iosVersion: String,
        simulatorModel: String,
        xcodeVersion: String,
        projectFileName: String,
        spmPackagesContainerPath: String,
        snapshotTestSchemes: [String]
    ) {
        self.repoRoot = repoRoot
        self.iosVersion = iosVersion
        self.simulatorModel = simulatorModel
        self.xcodeVersion = xcodeVersion
        self.projectFileName = projectFileName
        self.spmPackagesContainerPath = spmPackagesContainerPath
        self.snapshotTestSchemes = snapshotTestSchemes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repoRoot = try container.decode(String.self, forKey: .repoRoot)
        iosVersion = try container.decode(String.self, forKey: .iosVersion)
        simulatorModel = try container.decode(String.self, forKey: .simulatorModel)
        xcodeVersion = try container.decode(String.self, forKey: .xcodeVersion)
        projectFileName = try container.decode(String.self, forKey: .projectFileName)
        spmPackagesContainerPath = try container.decodeIfPresent(
            String.self,
            forKey: .spmPackagesContainerPath
        ) ?? "Packages"
        snapshotTestSchemes = try container.decodeIfPresent([String].self, forKey: .snapshotTestSchemes) ?? []
    }
}
