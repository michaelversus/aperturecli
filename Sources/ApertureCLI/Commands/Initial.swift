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
            let output: (String) -> Void = { message in
                Swift.print(message)
            }
            let compositionRoot = InitialCompositionRoot(
                fileSystem: fileSystem,
                prompter: TerminalSetupPrompter(output: output),
                schemeDiscoverer: SnapshotSchemeDiscoverer(fileSystem: fileSystem),
                configWriter: ApertureConfigWriter(fileSystem: fileSystem)
            )
            try await compositionRoot.run()
        }
    }
}
