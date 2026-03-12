@testable import ApertureCLI

final class MockSchemePostActionUpdater: SchemePostActionUpdating {
    struct Call {
        let schemePath: String
        let schemeName: String
        let projectName: String
    }

    var error: Error?
    private(set) var calls: [Call] = []

    func updatePostAction(at schemePath: String, schemeName: String, projectName: String) throws {
        calls.append(
            Call(
                schemePath: schemePath,
                schemeName: schemeName,
                projectName: projectName
            )
        )
        if let error {
            throw error
        }
    }
}
