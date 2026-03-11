import Foundation
@testable import ApertureCLI

final class MockDerivedDataLocator: DerivedDataLocatorProtocol {
    private(set) var locateCallCount = 0
    private(set) var receivedProjectName: String?

    let result: Result<DerivedDataPaths, Error>

    init(result: Result<DerivedDataPaths, Error>) {
        self.result = result
    }

    func locateDerivedData(projectName: String?) throws -> DerivedDataPaths {
        locateCallCount += 1
        receivedProjectName = projectName
        return try result.get()
    }
}
