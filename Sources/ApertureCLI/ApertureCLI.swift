import ArgumentParser

@main struct ApertureCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "CLI bridge for Aperture Studio app and Xcode",
        version: version,
        subcommands: [Initial.self],
        defaultSubcommand: Initial.self
    )
}

extension ApertureCLI {
    struct CommonOptions: ParsableArguments {
        /// Flag to enable verbose output for diagnostic purposes.
        @Flag(name: .shortAndLong, help: "Enable verbose output.")
        var verbose: Bool = false
    }
}
