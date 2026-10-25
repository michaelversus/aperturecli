enum HarnessBuildResult: Equatable, Sendable {
    case built(appPath: String)
    /// `log` is the compiler's full output, which belongs in the terminal.
    case failed(diagnostics: [PlaygroundDiagnostic], log: String)
}
