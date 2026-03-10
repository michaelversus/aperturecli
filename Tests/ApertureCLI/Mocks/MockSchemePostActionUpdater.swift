@testable import ApertureCLI

final class MockSchemePostActionUpdater: SchemePostActionUpdating {
    struct Call {
        let schemePath: String
        let schemeName: String
    }

    var error: Error?
    private(set) var calls: [Call] = []

    func updatePostAction(at schemePath: String, schemeName: String) throws {
        calls.append(Call(schemePath: schemePath, schemeName: schemeName))
        if let error {
            throw error
        }
    }
}
