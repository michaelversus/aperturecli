import Foundation
@testable import NSAssetsCLI

final class MockHarnessSimulatorController: HarnessSimulatorControlling, @unchecked Sendable {
    enum Call: Equatable {
        case setAppearance(PlaygroundTheme)
        case install(String)
        case relaunch
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    private let installError: (any Error)?

    init(installError: (any Error)? = nil) {
        self.installError = installError
    }

    var calls: [Call] { lock.withLock { recorded } }

    func setAppearance(_ theme: PlaygroundTheme) throws {
        lock.withLock { recorded.append(.setAppearance(theme)) }
    }

    func install(appPath: String) throws {
        lock.withLock { recorded.append(.install(appPath)) }
        if let installError { throw installError }
    }

    func relaunch() throws {
        lock.withLock { recorded.append(.relaunch) }
    }
}
