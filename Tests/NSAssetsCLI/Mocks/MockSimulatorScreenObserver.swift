import Foundation
@testable import NSAssetsCLI

actor MockSimulatorScreenObserver: SimulatorScreenObserving {
    private var digests: [String]
    private let droppedLines: [String]

    init(digests: [String], droppedLines: [String] = []) {
        self.digests = digests
        self.droppedLines = droppedLines
    }

    func screenDigest() async throws -> String {
        digests.removeFirst()
    }

    func droppedEventLogLines(since start: Date) async throws -> [String] {
        droppedLines
    }
}
