import ArgumentParser

extension NSAssetsCLI.Playground {
    struct Tap: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "tap",
            abstract: "Send one tap to a simulator and verify it landed",
            shouldDisplay: false
        )

        @Option(name: .long, help: "UDID of the simulator to tap. Never defaults to a booted one.")
        var udid: String

        @Option(name: .customLong("x"), help: "Horizontal position, 0 (left) to 1 (right).")
        var horizontal: Double

        @Option(name: .customLong("y"), help: "Vertical position, 0 (top) to 1 (bottom).")
        var vertical: Double

        func run() async throws {
            let observer = SimctlScreenObserver(udid: udid)
            let verifier = SimulatorTapVerifier(observer: observer, settleDuration: .milliseconds(800))
            let point = NormalizedPoint(horizontal: horizontal, vertical: vertical)

            let executor = PlaygroundCommandExecutor(session: LiveSimulatorSession(udid: udid))
            try await executor.run { session in
                let delivery = try await verifier.verify(tap: point, on: session)
                Swift.print(delivery.summary)
            }
        }
    }
}
