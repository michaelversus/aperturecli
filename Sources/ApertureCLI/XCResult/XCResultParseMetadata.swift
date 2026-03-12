import Foundation

struct XCResultParseMetadata: Codable, Equatable {
    let triggeredAt: String
    let schemeName: String
    let projectName: String
    let workspacePath: String?
}
