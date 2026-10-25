import Foundation

/// Builds the harness app for one component straight to the simulator with `swiftc`, with no Xcode project.
///
/// The harness directory holds the fixed app source and the two files that change per component.
///
/// `@unchecked Sendable`: `FileSystemProvider` and `CommandRunning` are not declared `Sendable`, so the compiler cannot
/// check this. It is safe because the channel presents one component at a time, so the builder is never used from two
/// tasks at once.
struct HarnessBuilder: HarnessBuilding, @unchecked Sendable {
    let fileSystem: FileSystemProvider
    let commandRunner: CommandRunning
    let harnessDirectory: String

    var isWarm: Bool {
        fileSystem.fileExists(atPath: harnessDirectory + "/Harness.app/Harness")
    }

    func build(_ request: PlaygroundComponentRequest, target: HarnessTarget) throws -> HarnessBuildResult {
        let sources = harnessDirectory + "/Sources"
        let appBundle = harnessDirectory + "/Harness.app"
        try fileSystem.createDirectory(atPath: sources, withIntermediateDirectories: true)
        try fileSystem.createDirectory(atPath: appBundle, withIntermediateDirectories: true)

        let entry = HarnessSourceGenerator.entry(kind: request.kind, expression: request.entry)
        // Only the component and its entry change per component; the app source and bundle description stay put.
        let appFile = (HarnessSourceGenerator.appFileName, HarnessSourceGenerator.appSource)
        let files = [
            appFile,
            (HarnessSourceGenerator.componentFileName, request.source),
            (HarnessSourceGenerator.entryFileName, entry.text)
        ]
        try writeIfChanged(appFile.1, toPath: "\(sources)/\(appFile.0)")
        for (name, contents) in files.dropFirst() {
            try fileSystem.writeFile(contents, toPath: "\(sources)/\(name)")
        }
        try writeIfChanged(
            HarnessSourceGenerator.infoPlist(minimumOSVersion: target.iOSVersion),
            toPath: appBundle + "/Info.plist"
        )

        do {
            _ = try commandRunner.run(
                executable: ExternalTools.xcrun,
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
                diagnostics: diagnostics(from: output, entry: entry),
                log: output
            )
        }
    }

    private func writeIfChanged(_ contents: String, toPath path: String) throws {
        if fileSystem.fileExists(atPath: path), (try? fileSystem.readFile(atPath: path)) == contents { return }
        try fileSystem.writeFile(contents, toPath: path)
    }

    private func diagnostics(from output: String, entry: HarnessEntrySource) -> [PlaygroundDiagnostic] {
        let parsed = SwiftDiagnosticParser(
            entryFirstLine: entry.firstExpressionLine,
            entryLineCount: entry.expressionLineCount
        ).parse(output)
        guard !parsed.contains(where: { $0.severity == .error }) else { return parsed }
        return parsed + [
            .harnessError(
                "The build failed without a compiler error that points at the code. "
                    + "See the CLI's terminal output for the full log."
            )
        ]
    }
}
