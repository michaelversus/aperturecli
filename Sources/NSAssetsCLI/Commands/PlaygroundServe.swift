import ArgumentParser
import Foundation

extension NSAssetsCLI.Playground {
    struct Serve: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "serve",
            abstract: "Serve a simulator to NSAssets Studio until stopped"
        )

        @Option(name: .long, help: "UDID of the booted simulator to serve. Never defaults to a booted one.")
        var udid: String

        @Flag(name: .long, help: .hidden)
        var debugViewer = false

        func run() async throws {
            let token = try PlaygroundTokenGenerator.make()
            let session = LiveSimulatorSession(udid: udid)
            let verifier = SimulatorTapVerifier(
                observer: SimctlScreenObserver(udid: udid),
                settleDuration: .milliseconds(800)
            )
            let server = PlaygroundChannelServer(
                session: session,
                token: token,
                verifier: verifier,
                output: { Swift.print($0) }
            )
            let runner = PlaygroundChannelRunner(
                server: server,
                token: token,
                simulatorUDID: udid,
                workingDirectory: FileManager.default.currentDirectoryPath,
                poster: DistributedNotificationPoster(),
                debugViewer: debugViewer ? PlaygroundDebugViewer(httpPort: 0) : nil,
                onReady: { Swift.print("Playground ready on 127.0.0.1:\($0). Press Ctrl-C to stop.") },
                onDebugViewerReady: { Swift.print("Debug viewer: http://127.0.0.1:\($0)/") }
            )

            let executor = PlaygroundCommandExecutor(session: session)
            let serving = Task {
                try await executor.run { _ in try await runner.run() }
            }
            // Cancelling on either signal lets the session and its HID connection shut down cleanly.
            let stopSignals = [SIGINT, SIGTERM].map { signalNumber in
                signal(signalNumber, SIG_IGN)
                let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
                source.setEventHandler { serving.cancel() }
                source.resume()
                return source
            }
            defer { stopSignals.forEach { $0.cancel() } }

            try await serving.value
        }
    }
}
