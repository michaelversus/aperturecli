import ArgumentParser

extension NSAssetsCLI.Playground {
    struct Probe: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "probe",
            abstract: "Report whether this machine can stream and drive the simulator"
        )

        @Option(name: .long, help: "Also check this booted simulator (Device Hub flag, framebuffer).")
        var udid: String?

        func run() async throws {
            let executor = PlaygroundCommandExecutor(session: LiveSimulatorSession(udid: udid))
            await executor.probe()
        }
    }
}
