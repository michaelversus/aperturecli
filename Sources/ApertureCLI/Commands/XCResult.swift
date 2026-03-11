import ArgumentParser
import Foundation

extension ApertureCLI {
    struct XCResult: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "xcresult",
            abstract: "XCResult inspection commands",
            subcommands: [Parse.self]
        )
    }
}

extension ApertureCLI.XCResult {
    struct Parse: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "parse",
            abstract: "Resolve the most recent scheme xcresult path in DerivedData"
        )

        @Option(name: .long, help: "Scheme name used to match xcresult files.")
        var scheme: String

        @Option(name: .long, help: "Xcode project name (without .xcodeproj).")
        var projectName: String

        func run() async throws {
            let fileSystem = FileSystem(fileManager: .default)
            let locator = DerivedDataLocator(fileSystem: fileSystem)
            let resolver = XCResultPathResolver(
                fileSystem: fileSystem,
                derivedDataLocator: locator
            )
            let executor = XCResultParseCommandExecutor(
                fileSystem: fileSystem,
                resolver: resolver,
                output: { line in Swift.print(line) }
            )

            try executor.run(schemeName: scheme, projectName: projectName)
        }
    }
}
