import ArgumentParser

extension NSAssetsCLI {
    /// Streams and drives a component in an iOS Simulator so NSAssets Studio can show a live playground.
    struct Playground: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "playground",
            abstract: "Live simulator playground commands",
            subcommands: [Probe.self, Serve.self, Tap.self, Frames.self]
        )
    }
}
