import ArgumentParser

extension NSAssetsCLI.Playground {
    struct Frames: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "frames",
            abstract: "Capture frames from a simulator and print the measured frame rate",
            shouldDisplay: false
        )

        @Option(name: .long, help: "UDID of the simulator to capture. Never defaults to a booted one.")
        var udid: String

        @Option(name: .long, help: "How long to capture.")
        var seconds: Int = 10

        @Option(name: .long, help: "Write the first captured frame to this path as a JPEG.")
        var saveFirst: String?

        func run() async throws {
            let executor = PlaygroundCommandExecutor(session: LiveSimulatorSession(udid: udid))
            let capture = FrameCaptureRun(seconds: seconds, saveFirstFramePath: saveFirst)

            try await executor.run { session in
                let result = try await capture.run(on: session)
                Swift.print("Private framebuffer: \(result.summary)")
            }
        }
    }
}
