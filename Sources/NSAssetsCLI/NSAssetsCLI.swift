import ArgumentParser

@main struct NSAssetsCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "CLI bridge for NSAssets Studio app and Xcode",
        version: version,
        subcommands: [Initial.self, Schemes.self, XCResult.self],
        defaultSubcommand: Initial.self
    )
}

extension NSAssetsCLI {
    struct CommonOptions: ParsableArguments {
        /// Flag to enable verbose output for diagnostic purposes.
        @Flag(name: .shortAndLong, help: "Enable verbose output.")
        var verbose: Bool = false
    }
}
