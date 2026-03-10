import ArgumentParser
import Foundation

extension ApertureCLI {
    struct Initial: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "CLI setup wizard"
        )

        func run() async throws {
            let fileSystem = FileSystem(fileManager: .default)
            let compositionRoot = InitialCompositionRoot(fileSystem: fileSystem)
            try await compositionRoot.run()
            
        }
    }
}
