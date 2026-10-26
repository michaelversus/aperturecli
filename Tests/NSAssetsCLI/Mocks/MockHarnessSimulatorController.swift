import Foundation
@testable import NSAssetsCLI

final class MockHarnessSimulatorController: HarnessSimulatorControlling, @unchecked Sendable {
    enum Call: Equatable {
        case setAppearance(PlaygroundTheme)
        case install(String)
        case relaunch
        case clear
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    private let installError: (any Error)?
    private let clearError: (any Error)?

    init(installError: (any Error)? = nil, clearError: (any Error)? = nil) {
        self.installError = installError
        self.clearError = clearError
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

    func clear() throws {
        lock.withLock { recorded.append(.clear) }
        if let clearError { throw clearError }
    }
}
