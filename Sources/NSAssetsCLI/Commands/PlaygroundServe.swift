import ArgumentParser
import Foundation

extension NSAssetsCLI.Playground {
    struct Serve: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "serve",
            abstract: "Serve a simulator to NSAssets Studio until stopped"
        )

        @Option(
            name: .long,
            help: "UDID of the booted simulator to serve. Defaults to the one booted simulator .nsassets.json asks for."
        )
        var udid: String?

        @Flag(name: .long, help: .hidden)
        var debugViewer = false

        @Flag(name: .long, help: "Check every tap by comparing screens and the guest log. Adds seconds to each tap.")
        var verifyTaps = false

        @Flag(name: .long, help: .hidden)
        var showMockComponent = false

        func run() async throws {
            let udid = try udid ?? ConfiguredSimulatorResolver(
                configLoader: NSAssetsConfigLoader(fileSystem: FileSystem()),
                commandRunner: SubprocessRunner(),
                workingDirectory: FileManager.default.currentDirectoryPath
            ).resolve()
            let token = try PlaygroundTokenGenerator.make()
            let session = LiveSimulatorSession(udid: udid)
            let verifier = verifyTaps
                ? SimulatorTapVerifier(observer: SimctlScreenObserver(udid: udid), settleDuration: .milliseconds(800))
                : nil
            let presenter = makePresenter(udid: udid)
            let server = PlaygroundChannelServer(
                session: session,
                token: token,
                verifier: verifier,
                componentPresenter: presenter,
                output: { Swift.print($0) }
            )
            let showMock = showMockComponent
            let runner = PlaygroundChannelRunner(
                server: server,
                token: token,
                simulatorUDID: udid,
                workingDirectory: FileManager.default.currentDirectoryPath,
                poster: DistributedNotificationPoster(),
                debugViewer: debugViewer ? PlaygroundDebugViewer() : nil,
                onReady: { port in
                    Swift.print("Playground ready on 127.0.0.1:\(port). Press Ctrl-C to stop.")
                    guard showMock else { return }
                    server.present(.mock) { Swift.print("Mock component: \($0.summary)") }
                },
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

        /// Builds the harness under the user's caches for this repository, and drives this simulator's harness app.
        private func makePresenter(udid: String) -> PlaygroundComponentPresenter {
            let fileSystem = FileSystem()
            let harnessDirectory = HarnessCacheLocator.directory(
                forWorkingDirectory: FileManager.default.currentDirectoryPath,
                libraryDirectory: fileSystem.libraryDirectory()
            )
            return PlaygroundComponentPresenter(
                builder: HarnessBuilder(
                    fileSystem: fileSystem,
                    commandRunner: SubprocessRunner(),
                    harnessDirectory: harnessDirectory
                ),
                controller: SimctlHarnessController(udid: udid, commandRunner: SubprocessRunner()),
                resolveTarget: { try HarnessTargetResolver(commandRunner: SubprocessRunner(), udid: udid).resolve() },
                importDiagnostics: { source, target in
                    let modules = HarnessSDKModules(sdkPath: target.sdkPath, fileSystem: FileSystem())
                    return HarnessImportChecker(isSystemModule: modules.isSystemModule).diagnostics(forSource: source)
                },
                output: { Swift.print($0) }
            )
        }
    }
}
