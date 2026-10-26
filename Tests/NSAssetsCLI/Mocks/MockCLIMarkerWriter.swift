import Foundation
@testable import NSAssetsCLI

final class MockCLIMarkerWriter: CLIMarkerWriting {
    private(set) var writtenRootPaths: [String] = []

    func write(atRootPath rootPath: String) {
        writtenRootPaths.append(rootPath)
    }
}
