import ArgumentParser
import Foundation

extension ApertureCLI {
    struct Test: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "test",
            abstract: "Test lifecycle commands",
            subcommands: [Executed.self]
        )
    }
}

extension ApertureCLI.Test {
    struct Executed: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "executed",
            abstract: "Emit test-executed metadata for deferred xcresult processing"
        )

        @Option(name: .long, help: "Scheme name used for test execution.")
        var scheme: String

        @Option(name: .long, help: "Xcode project name (without .xcodeproj).")
        var projectName: String

        @Option(name: .long, help: "Workspace path used to derive repo root for artifacts.")
        var workspacePath: String?

        func run() async throws {
            let fileSystem = FileSystem(fileManager: .default)
            let executor = XCResultMetadataCommandExecutor(
                fileSystem: fileSystem,
                output: { line in Swift.print(line) }
            )

            try executor.run(
                schemeName: scheme,
                projectName: projectName,
                workspacePath: workspacePath
            )
        }
    }
}
