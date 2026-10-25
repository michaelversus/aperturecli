import Foundation

/// Builds the harness app for one component straight to the simulator with `swiftc`, with no Xcode project.
///
/// The harness directory holds the fixed app source and the two files that change per component. Marked
/// `@unchecked Sendable` because the channel runs one component at a time, so its collaborators are never shared
/// between tasks.
struct HarnessBuilder: HarnessBuilding, @unchecked Sendable {
    let fileSystem: FileSystemProvider
    let commandRunner: CommandRunning
    let harnessDirectory: String

    func build(_ request: PlaygroundComponentRequest, target: HarnessTarget) throws -> HarnessBuildResult {
        let sources = harnessDirectory + "/Sources"
        let appBundle = harnessDirectory + "/Harness.app"
        try fileSystem.createDirectory(atPath: sources, withIntermediateDirectories: true)
        try fileSystem.createDirectory(atPath: appBundle, withIntermediateDirectories: true)

        let entry = HarnessSourceGenerator.entry(kind: request.kind, expression: request.entry)
        let files = [
            (HarnessSourceGenerator.appFileName, HarnessSourceGenerator.appSource),
            (HarnessSourceGenerator.componentFileName, request.source),
            (HarnessSourceGenerator.entryFileName, entry.text)
        ]
        for (name, contents) in files {
            try fileSystem.writeFile(contents, toPath: "\(sources)/\(name)")
        }
        try fileSystem.writeFile(
            HarnessSourceGenerator.infoPlist(minimumOSVersion: target.iOSVersion),
            toPath: appBundle + "/Info.plist"
        )

        do {
            _ = try commandRunner.run(
                executable: "/usr/bin/xcrun",
                arguments: [
                    "swiftc", "-sdk", target.sdkPath,
                    "-target", "arm64-apple-ios\(target.iOSVersion)-simulator",
                    "-parse-as-library", "-Onone", "-module-name", "Harness",
                    "-o", appBundle + "/Harness"
                ] + files.map { "\(sources)/\($0.0)" }
            )
            return .built(appPath: appBundle)
        } catch let SubprocessRunnerError.commandFailed(_, _, _, output) {
            return .failed(
                diagnostics: diagnostics(from: output, entryFirstLine: entry.firstExpressionLine),
                log: output
            )
        }
    }

    private func diagnostics(from output: String, entryFirstLine: Int) -> [PlaygroundDiagnostic] {
        let parsed = SwiftDiagnosticParser(entryFirstLine: entryFirstLine).parse(output)
        guard !parsed.contains(where: { $0.severity == .error }) else { return parsed }
        return parsed + [
            PlaygroundDiagnostic(
                file: .harness,
                line: nil,
                column: nil,
                severity: .error,
                message: "The build failed without a compiler error that points at the code. "
                    + "See the CLI's terminal output for the full log."
            )
        ]
    }
}
