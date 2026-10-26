import Foundation
import Testing
@testable import NSAssetsCLI

struct HarnessAssetCompilerTests {
    private let target = HarnessTarget(sdkPath: "/sdk", iOSVersion: "27.0")
    private let logo = PlaygroundAssetEntry(
        catalog: "Assets",
        kind: .imageset,
        path: "/repo/Assets.xcassets/logo.imageset"
    )
    private let brand = PlaygroundAssetEntry(
        catalog: "Assets",
        kind: .colorset,
        path: "/repo/Assets.xcassets/brand.colorset"
    )

    @Test
    func copiesTheEntriesIntoAMinimalCatalogAndCompilesItIntoTheApp() throws {
        let fileSystem = MockFileSystem(existingPaths: [logo.path, brand.path])
        let runner = MockCommandRunner(queuedResults: [.success("")])

        try compiler(fileSystem, runner).prepare([logo, brand], target: target, appBundle: "/cache/Harness.app")

        #expect(fileSystem.copyOperations == [
            .init(source: logo.path, destination: "/cache/Assets.xcassets/logo.imageset"),
            .init(source: brand.path, destination: "/cache/Assets.xcassets/brand.colorset")
        ])
        #expect(fileSystem.writeOperations.map(\.path).contains("/cache/Assets.xcassets/Contents.json"))
        #expect(runner.invocations.map(\.arguments) == [[
            "actool", "/cache/Assets.xcassets", "--compile", "/cache/Harness.app",
            "--platform", "iphonesimulator", "--minimum-deployment-target", "27.0",
            "--target-device", "iphone", "--target-device", "ipad",
            "--output-partial-info-plist", "/cache/assets-partial.plist"
        ]])
        #expect(fileSystem.writeOperations.map(\.path).contains("/cache/assets.fingerprint"))
    }

    @Test
    func theFirstEntryOfANameAndKindWins() throws {
        let other = PlaygroundAssetEntry(catalog: "Other", kind: .imageset, path: "/repo/Other.xcassets/logo.imageset")
        let fileSystem = MockFileSystem(existingPaths: [logo.path, other.path])

        try compiler(fileSystem, MockCommandRunner(queuedResults: [.success("")]))
            .prepare([logo, other], target: target, appBundle: "/cache/Harness.app")

        #expect(fileSystem.copyOperations.map(\.source) == [logo.path])
    }

    @Test
    func unchangedEntriesAreNotRebuilt() throws {
        let first = MockFileSystem(existingPaths: [logo.path])
        try compiler(first, MockCommandRunner(queuedResults: [.success("")]))
            .prepare([logo], target: target, appBundle: "/cache/Harness.app")
        let fingerprint = try #require(first.writeOperations.first { $0.path == "/cache/assets.fingerprint" }).contents

        let fileSystem = MockFileSystem(
            existingPaths: [logo.path, "/cache/Harness.app/Assets.car"],
            fileContentsByPath: ["/cache/assets.fingerprint": fingerprint]
        )
        let runner = MockCommandRunner()

        try compiler(fileSystem, runner).prepare([logo], target: target, appBundle: "/cache/Harness.app")

        #expect(runner.invocations.isEmpty)
        #expect(fileSystem.copyOperations.isEmpty)
    }

    @Test
    func changedEntriesOrADifferentDeploymentTargetAreRebuilt() throws {
        let first = MockFileSystem(existingPaths: [logo.path])
        try compiler(first, MockCommandRunner(queuedResults: [.success("")]))
            .prepare([logo], target: target, appBundle: "/cache/Harness.app")
        let fingerprint = try #require(first.writeOperations.first { $0.path == "/cache/assets.fingerprint" }).contents
        let existing = MockFileSystem(
            existingPaths: [logo.path, brand.path, "/cache/Harness.app/Assets.car"],
            fileContentsByPath: ["/cache/assets.fingerprint": fingerprint]
        )

        let runner = MockCommandRunner(queuedResults: [.success("")])
        try compiler(existing, runner).prepare([logo, brand], target: target, appBundle: "/cache/Harness.app")
        #expect(runner.invocations.count == 1)

        let newerTarget = MockCommandRunner(queuedResults: [.success("")])
        try compiler(existing, newerTarget)
            .prepare([logo], target: HarnessTarget(sdkPath: "/sdk", iOSVersion: "28.0"), appBundle: "/cache/Harness.app")
        #expect(newerTarget.invocations.count == 1)
    }

    @Test
    func withoutEntriesWhatAnEarlierRequestLeftBehindIsRemoved() throws {
        let fileSystem = MockFileSystem(existingPaths: ["/cache/Harness.app/Assets.car", "/cache/assets.fingerprint"])
        let runner = MockCommandRunner()

        try compiler(fileSystem, runner).prepare([], target: target, appBundle: "/cache/Harness.app")

        #expect(runner.invocations.isEmpty)
        #expect(Set(fileSystem.removeItemOperations.map(\.path)) == ["/cache/Harness.app/Assets.car", "/cache/assets.fingerprint"])
    }

    @Test
    func refusedEntriesStopBeforeAnythingIsCopiedOrCompiled() {
        let bad = PlaygroundAssetEntry(catalog: "Assets", kind: .imageset, path: "/etc/passwd")
        let fileSystem = MockFileSystem(existingPaths: ["/etc/passwd"])
        let runner = MockCommandRunner()

        #expect(throws: HarnessAssetError.self) {
            try compiler(fileSystem, runner).prepare([bad], target: target, appBundle: "/cache/Harness.app")
        }
        #expect(fileSystem.copyOperations.isEmpty)
        #expect(runner.invocations.isEmpty)
    }

    @Test
    func anActoolFailureKeepsItsOutputAndRecordsNoFingerprint() {
        let failure = SubprocessRunnerError.commandFailed(
            executable: ExternalTools.xcrun,
            arguments: [],
            exitCode: 1,
            output: "error: bad Contents.json"
        )
        let fileSystem = MockFileSystem(existingPaths: [logo.path])

        #expect(throws: HarnessAssetError.compilerFailed(output: "error: bad Contents.json")) {
            try compiler(fileSystem, MockCommandRunner(queuedResults: [.failure(failure)]))
                .prepare([logo], target: target, appBundle: "/cache/Harness.app")
        }
        #expect(!fileSystem.writeOperations.map(\.path).contains("/cache/assets.fingerprint"))
    }

    private func compiler(_ fileSystem: MockFileSystem, _ runner: MockCommandRunner) -> HarnessAssetCompiler {
        HarnessAssetCompiler(fileSystem: fileSystem, commandRunner: runner, harnessDirectory: "/cache")
    }
}
