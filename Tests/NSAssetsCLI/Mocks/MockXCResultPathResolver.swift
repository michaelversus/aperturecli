import Foundation
@testable import NSAssetsCLI

final class MockXCResultPathResolver: XCResultPathResolving {
    private(set) var callCount = 0
    private(set) var receivedSchemeName: String?
    private(set) var receivedProjectName: String?

    let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func resolvePath(schemeName: String, projectName: String) throws -> String {
        callCount += 1
        receivedSchemeName = schemeName
        receivedProjectName = projectName
        return try result.get()
    }
}
