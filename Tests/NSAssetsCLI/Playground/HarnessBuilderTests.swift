import Foundation
import Testing
@testable import NSAssetsCLI

struct HarnessBuilderTests {
    private let target = HarnessTarget(sdkPath: "/sdk/iPhoneSimulator.sdk", iOSVersion: "27.0")
    private let request = PlaygroundComponentRequest(
        id: "1",
        kind: .swiftUIView,
        source: "import SwiftUI\nstruct CounterView: View { var body: some View { Text(\"x\") } }",
        entry: "CounterView()",
        snapshotName: "n",
        theme: .light
    )

    @Test
    func writesTheHarnessSourcesAndTheBundleDescription() throws {
        let fileSystem = MockFileSystem()
        let builder = HarnessBuilder(
            fileSystem: fileSystem,
            commandRunner: MockCommandRunner(queuedResults: [.success("")]),
            harnessDirectory: "/cache/h1"
        )

        _ = try builder.build(request, target: target)

        let writes = Dictionary(uniqueKeysWithValues: fileSystem.writeOperations.map { ($0.path, $0.contents) })
        #expect(writes["/cache/h1/Sources/HarnessApp.swift"] == HarnessSourceGenerator.appSource)
        #expect(writes["/cache/h1/Sources/ComponentSource.swift"] == request.source)
        let entry = HarnessSourceGenerator.entry(kind: .swiftUIView, expression: "CounterView()")
        #expect(writes["/cache/h1/Sources/PlaygroundEntry.swift"] == entry.text)
        let plist = HarnessSourceGenerator.infoPlist(minimumOSVersion: "27.0")
        #expect(writes["/cache/h1/Harness.app/Info.plist"] == plist)
        let directories = fileSystem.createDirectoryOperations.map(\.path)
        #expect(directories.contains("/cache/h1/Sources"))
        #expect(directories.contains("/cache/h1/Harness.app"))
    }

    @Test
    func theFixedAppSourceAndBundleDescriptionAreNotRewrittenWhenUnchanged() throws {
        let plist = HarnessSourceGenerator.infoPlist(minimumOSVersion: "27.0")
        let fileSystem = MockFileSystem(
            existingPaths: ["/cache/h1/Sources/HarnessApp.swift", "/cache/h1/Harness.app/Info.plist"],
            fileContentsByPath: [
                "/cache/h1/Sources/HarnessApp.swift": HarnessSourceGenerator.appSource,
                "/cache/h1/Harness.app/Info.plist": plist
            ]
        )
        let builder = HarnessBuilder(
            fileSystem: fileSystem,
            commandRunner: MockCommandRunner(queuedResults: [.success("")]),
            harnessDirectory: "/cache/h1"
        )

        _ = try builder.build(request, target: target)

        let written = fileSystem.writeOperations.map(\.path)
        #expect(!written.contains("/cache/h1/Sources/HarnessApp.swift"))
        #expect(!written.contains("/cache/h1/Harness.app/Info.plist"))
        #expect(written.contains("/cache/h1/Sources/ComponentSource.swift"))
        #expect(written.contains("/cache/h1/Sources/PlaygroundEntry.swift"))
    }

    @Test
    func aChangedFixedFileIsRewritten() throws {
        let fileSystem = MockFileSystem(
            existingPaths: ["/cache/h1/Sources/HarnessApp.swift"],
            fileContentsByPath: ["/cache/h1/Sources/HarnessApp.swift": "old"]
        )
        let builder = HarnessBuilder(
            fileSystem: fileSystem,
            commandRunner: MockCommandRunner(queuedResults: [.success("")]),
            harnessDirectory: "/cache/h1"
        )

        _ = try builder.build(request, target: target)

        #expect(fileSystem.writeOperations.map(\.path).contains("/cache/h1/Sources/HarnessApp.swift"))
    }

    @Test
    func theHarnessIsWarmOnceItsExecutableExists() {
        let cold = HarnessBuilder(
            fileSystem: MockFileSystem(),
            commandRunner: MockCommandRunner(),
            harnessDirectory: "/c"
        )
        let warm = HarnessBuilder(
            fileSystem: MockFileSystem(existingPaths: ["/c/Harness.app/Harness"]),
            commandRunner: MockCommandRunner(),
            harnessDirectory: "/c"
        )

        #expect(!cold.isWarm)
        #expect(warm.isWarm)
    }

    @Test
    func compilesAllThreeSourcesForTheSimulatorAtTheRuntimeVersion() throws {
        let runner = MockCommandRunner(queuedResults: [.success("")])
        let builder = HarnessBuilder(fileSystem: MockFileSystem(), commandRunner: runner, harnessDirectory: "/cache/h1")

        let result = try builder.build(request, target: target)

        let invocation = try #require(runner.invocations.first)
        #expect(invocation.executable == "/usr/bin/xcrun")
        let arguments = invocation.arguments
        #expect(arguments.starts(with: ["swiftc", "-sdk", "/sdk/iPhoneSimulator.sdk"]))
        #expect(arguments.contains("arm64-apple-ios27.0-simulator"))
        #expect(arguments.contains("-parse-as-library"))
        #expect(arguments.contains("/cache/h1/Harness.app/Harness"))
        #expect(arguments.contains("/cache/h1/Sources/HarnessApp.swift"))
        #expect(arguments.contains("/cache/h1/Sources/ComponentSource.swift"))
        #expect(arguments.contains("/cache/h1/Sources/PlaygroundEntry.swift"))
        #expect(result == .built(appPath: "/cache/h1/Harness.app"))
    }

    @Test
    func assetsAreCompiledIntoTheAppBeforeTheHarnessIsBuilt() throws {
        let logo = "/repo/Assets.xcassets/logo.imageset"
        let runner = MockCommandRunner(queuedResults: [.success(""), .success("")])
        let builder = HarnessBuilder(
            fileSystem: MockFileSystem(existingPaths: [logo]),
            commandRunner: runner,
            harnessDirectory: "/cache/h1"
        )
        var withAssets = request
        withAssets.assets = [PlaygroundAssetEntry(catalog: "Assets", kind: .imageset, path: logo)]

        let result = try builder.build(withAssets, target: target)

        #expect(runner.invocations.map { $0.arguments.first } == ["actool", "swiftc"])
        #expect(result == .built(appPath: "/cache/h1/Harness.app"))
    }

    @Test
    func aRefusedAssetFailsTheBuildWithAHarnessDiagnosticAndNeverCompiles() throws {
        let runner = MockCommandRunner()
        let builder = HarnessBuilder(fileSystem: MockFileSystem(), commandRunner: runner, harnessDirectory: "/cache/h1")
        var withAssets = request
        withAssets.assets = [PlaygroundAssetEntry(catalog: "Assets", kind: .imageset, path: "/etc/passwd")]

        let result = try builder.build(withAssets, target: target)

        guard case let .failed(diagnostics, _) = result else {
            Issue.record("expected a failed build, got \(result)")
            return
        }
        #expect(diagnostics.first?.file == .harness)
        #expect(runner.invocations.isEmpty)
    }

    @Test
    func anActoolFailureIsADiagnosticWithTheLogNotACrash() throws {
        let logo = "/repo/Assets.xcassets/logo.imageset"
        let failure = SubprocessRunnerError.commandFailed(
            executable: "/usr/bin/xcrun", arguments: [], exitCode: 1, output: "error: bad catalog"
        )
        let runner = MockCommandRunner(queuedResults: [.failure(failure)])
        let builder = HarnessBuilder(
            fileSystem: MockFileSystem(existingPaths: [logo]),
            commandRunner: runner,
            harnessDirectory: "/cache/h1"
        )
        var withAssets = request
        withAssets.assets = [PlaygroundAssetEntry(catalog: "Assets", kind: .imageset, path: logo)]

        let result = try builder.build(withAssets, target: target)

        guard case let .failed(diagnostics, log) = result else {
            Issue.record("expected a failed build, got \(result)")
            return
        }
        #expect(diagnostics.first?.file == .harness)
        #expect(log == "error: bad catalog")
        #expect(runner.invocations.count == 1)
    }

    @Test
    func aCompileErrorBecomesDiagnosticsInTheSentCodeAndKeepsTheFullLog() throws {
        let log = """
        /cache/h1/Sources/ComponentSource.swift:2:30: error: cannot find 'Missing' in scope
        /cache/h1/Sources/ComponentSource.swift:2:30: note: did you mean something
        """
        let failure = SubprocessRunnerError.commandFailed(
            executable: "/usr/bin/xcrun", arguments: [], exitCode: 1, output: log
        )
        let builder = HarnessBuilder(
            fileSystem: MockFileSystem(),
            commandRunner: MockCommandRunner(queuedResults: [.failure(failure)]),
            harnessDirectory: "/cache/h1"
        )

        let result = try builder.build(request, target: target)

        guard case let .failed(diagnostics, fullLog) = result else {
            Issue.record("expected a failed build, got \(result)")
            return
        }
        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.file == .component)
        #expect(diagnostics.first?.line == 2)
        #expect(diagnostics.first?.message == "cannot find 'Missing' in scope")
        #expect(fullLog == log)
    }

    @Test
    func aFailureWithNothingParseableStillExplainsItself() throws {
        let failure = SubprocessRunnerError.commandFailed(
            executable: "/usr/bin/xcrun", arguments: [], exitCode: 70, output: "Segmentation fault"
        )
        let builder = HarnessBuilder(
            fileSystem: MockFileSystem(),
            commandRunner: MockCommandRunner(queuedResults: [.failure(failure)]),
            harnessDirectory: "/cache/h1"
        )

        let result = try builder.build(request, target: target)

        guard case let .failed(diagnostics, _) = result else {
            Issue.record("expected a failed build, got \(result)")
            return
        }
        #expect(diagnostics.first?.file == .harness)
        #expect(diagnostics.first?.severity == .error)
        #expect(diagnostics.first?.message.contains("terminal") == true)
    }

    @Test
    func anErrorThatIsNotACompileFailureIsNotSwallowed() {
        struct Unexpected: Error {}
        let builder = HarnessBuilder(
            fileSystem: MockFileSystem(),
            commandRunner: MockCommandRunner(queuedResults: [.failure(Unexpected())]),
            harnessDirectory: "/cache/h1"
        )

        #expect(throws: Unexpected.self) { try builder.build(request, target: target) }
    }
}
