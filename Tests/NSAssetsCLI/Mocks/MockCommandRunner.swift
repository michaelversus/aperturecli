import Foundation
@testable import NSAssetsCLI

final class MockCommandRunner: CommandRunning {
    struct Invocation: Equatable {
        let executable: String
        let arguments: [String]
    }

    private(set) var invocations: [Invocation] = []
    private var queuedResults: [Result<String, Error>]

    init(queuedResults: [Result<String, Error>] = []) {
        self.queuedResults = queuedResults
    }

    func run(executable: String, arguments: [String]) throws -> String {
        invocations.append(Invocation(executable: executable, arguments: arguments))
        guard !queuedResults.isEmpty else {
            throw NSError(domain: "MockCommandRunner", code: 1, userInfo: nil)
        }
        return try queuedResults.removeFirst().get()
    }
}
