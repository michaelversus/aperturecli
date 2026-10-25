import Foundation
import Testing
@testable import NSAssetsCLI

struct HarnessCacheLocatorTests {
    private let library = URL(fileURLWithPath: "/Users/dev/Library", isDirectory: true)

    @Test
    func theHarnessLivesInTheUsersCachesDirectory() {
        let directory = HarnessCacheLocator.directory(forWorkingDirectory: "/repo", libraryDirectory: library)

        #expect(directory.hasPrefix("/Users/dev/Library/Caches/NSAssetsCLI/playground/"))
        #expect(directory.split(separator: "/").last?.count == 12)
    }

    @Test
    func theSameRepositoryAlwaysGetsTheSameHarness() {
        let first = HarnessCacheLocator.directory(forWorkingDirectory: "/repo", libraryDirectory: library)
        let second = HarnessCacheLocator.directory(forWorkingDirectory: "/repo", libraryDirectory: library)

        #expect(first == second)
    }

    @Test
    func differentRepositoriesGetDifferentHarnesses() {
        let first = HarnessCacheLocator.directory(forWorkingDirectory: "/repo-a", libraryDirectory: library)
        let second = HarnessCacheLocator.directory(forWorkingDirectory: "/repo-b", libraryDirectory: library)

        #expect(first != second)
    }
}
