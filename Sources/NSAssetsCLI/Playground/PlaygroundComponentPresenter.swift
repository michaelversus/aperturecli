import Foundation

/// Shows a component in the simulator: refuses code that imports outside the SDK, builds the harness, applies the
/// theme, then installs and launches it. Problems become a failed status, never a crash, and a compiler failure's
/// full log goes to the terminal.
struct PlaygroundComponentPresenter: PlaygroundComponentPresenting {
    let builder: any HarnessBuilding
    let controller: any HarnessSimulatorControlling
    let resolveTarget: @Sendable () throws -> HarnessTarget
    let importDiagnostics: @Sendable (_ source: String, _ target: HarnessTarget) -> [PlaygroundDiagnostic]
    let output: @Sendable (String) -> Void

    func present(
        _ request: PlaygroundComponentRequest,
        report: @Sendable (PlaygroundComponentStatus) -> Void
    ) async {
        let message = builder.isWarm
            ? "Building the component…"
            : "Preparing the harness. The first build in a repository takes a few seconds longer…"
        report(PlaygroundComponentStatus(id: request.id, state: .building, message: message))
        do {
            let target = try resolveTarget()
            let imports = importDiagnostics(request.source, target)
            guard imports.isEmpty else {
                report(
                    failure(
                        for: request,
                        message: "The component imports modules the playground cannot see.",
                        diagnostics: imports
                    )
                )
                return
            }
            switch try builder.build(request, target: target) {
            case let .built(appPath):
                try controller.setAppearance(request.theme)
                try controller.install(appPath: appPath)
                try controller.relaunch()
                report(PlaygroundComponentStatus(id: request.id, state: .ready))
            case let .failed(diagnostics, log):
                output(log)
                report(failure(for: request, message: "The component did not compile.", diagnostics: diagnostics))
            }
        } catch {
            report(failure(for: request, message: error.localizedDescription))
        }
    }

    private func failure(
        for request: PlaygroundComponentRequest,
        message: String,
        diagnostics: [PlaygroundDiagnostic] = []
    ) -> PlaygroundComponentStatus {
        PlaygroundComponentStatus(id: request.id, state: .failed, message: message, diagnostics: diagnostics)
    }
}
