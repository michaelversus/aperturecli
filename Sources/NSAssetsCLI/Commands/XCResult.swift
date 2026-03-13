import ArgumentParser
import Foundation

extension NSAssetsCLI {
    struct XCResult: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "xcresult",
            abstract: "XCResult inspection commands",
            subcommands: [Parse.self]
        )
    }
}

extension NSAssetsCLI.XCResult {
    struct Parse: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "parse",
            abstract: "Parse the most recent scheme xcresult in DerivedData"
        )

        @Option(name: .long, help: "Scheme name used to match xcresult files.")
        var scheme: String

        @Option(name: .long, help: "Xcode project name (without .xcodeproj).")
        var projectName: String

        @Option(name: .long, help: "Workspace path used to derive repo root for artifacts.")
        var workspacePath: String?

        func run() async throws {
            let fileSystem = FileSystem(fileManager: .default)
            let locator = DerivedDataLocator(fileSystem: fileSystem)
            let resolver = XCResultPathResolver(
                fileSystem: fileSystem,
                derivedDataLocator: locator
            )
            let commandRunner = SubprocessRunner()
            let xcresultToolClient = XCResultToolClient(
                commandRunner: commandRunner,
                fileSystem: fileSystem
            )
            let appBridge = AppBridge(
                appRunningChecker: RunningApplicationChecker(),
                appLauncher: OpenCommandAppLauncher(commandRunner: commandRunner),
                userPrompter: TerminalUserConfirmationPrompter(output: { line in Swift.print(line) }),
                notificationPoster: DistributedNotificationPoster(),
                output: { line in Swift.print(line) }
            )
            let executor = XCResultParseCommandExecutor(
                fileSystem: fileSystem,
                resolver: resolver,
                xcresultToolClient: xcresultToolClient,
                appBridge: appBridge,
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
