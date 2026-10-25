import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundComponentPresenterTests {
    private let target = HarnessTarget(sdkPath: "/sdk", iOSVersion: "27.0")
    private let request = PlaygroundComponentRequest(
        id: "req-1",
        kind: .swiftUIView,
        source: "import SwiftUI\nstruct A: View { var body: some View { Text(\"a\") } }",
        entry: "A()",
        snapshotName: "n",
        theme: .dark
    )

    @Test
    func buildsInstallsAndLaunchesThenReportsReady() async {
        let builder = MockHarnessBuilder(result: .success(.built(appPath: "/cache/Harness.app")))
        let controller = MockHarnessSimulatorController()
        let statuses = StatusRecorder()
        let presenter = makePresenter(builder: builder, controller: controller)

        await presenter.present(request, report: statuses.record)

        #expect(statuses.statuses.map(\.state) == [.building, .ready])
        #expect(statuses.statuses.allSatisfy { $0.id == "req-1" })
        #expect(builder.builds.first?.target == target)
        #expect(controller.calls == [.setAppearance(.dark), .install("/cache/Harness.app"), .relaunch])
    }

    @Test
    func theFirstBuildInARepositoryIsMarkedAsTheSlowOne() async {
        let builder = MockHarnessBuilder(result: .success(.built(appPath: "/x")), isWarm: false)
        let statuses = StatusRecorder()
        let presenter = makePresenter(builder: builder, controller: MockHarnessSimulatorController())

        await presenter.present(request, report: statuses.record)

        #expect(statuses.statuses.first?.message?.contains("first build") == true)
    }

    @Test
    func laterBuildsAreNotMarkedAsTheSlowOne() async {
        let builder = MockHarnessBuilder(result: .success(.built(appPath: "/x")), isWarm: true)
        let statuses = StatusRecorder()
        let presenter = makePresenter(builder: builder, controller: MockHarnessSimulatorController())

        await presenter.present(request, report: statuses.record)

        #expect(statuses.statuses.first?.message?.contains("first build") == false)
    }

    @Test
    func aModuleOutsideTheSDKFailsBeforeAnythingIsBuilt() async {
        let builder = MockHarnessBuilder(result: .success(.built(appPath: "/x")))
        let controller = MockHarnessSimulatorController()
        let statuses = StatusRecorder()
        let presenter = makePresenter(builder: builder, controller: controller, importDiagnostics: { _, _ in
            [PlaygroundDiagnostic(file: .component, line: 2, column: nil, severity: .error, message: "Module 'X'")]
        })

        await presenter.present(request, report: statuses.record)

        #expect(statuses.statuses.map(\.state) == [.building, .failed])
        #expect(statuses.statuses.last?.diagnostics.first?.message == "Module 'X'")
        #expect(builder.builds.isEmpty)
        #expect(controller.calls.isEmpty)
    }

    @Test
    func aFailedBuildReportsDiagnosticsAndPrintsTheFullLog() async {
        let diagnostic = PlaygroundDiagnostic(file: .component, line: 4, column: 1, severity: .error, message: "boom")
        let builder = MockHarnessBuilder(result: .success(.failed(diagnostics: [diagnostic], log: "FULL COMPILER LOG")))
        let controller = MockHarnessSimulatorController()
        let statuses = StatusRecorder()
        let output = OutputRecorder()
        let presenter = makePresenter(builder: builder, controller: controller, output: output.record)

        await presenter.present(request, report: statuses.record)

        #expect(statuses.statuses.map(\.state) == [.building, .failed])
        #expect(statuses.statuses.last?.diagnostics == [diagnostic])
        #expect(output.text.contains("FULL COMPILER LOG"))
        #expect(controller.calls.isEmpty)
    }

    @Test
    func aSimulatorProblemIsReportedAsAFailure() async {
        struct InstallFailed: Error, LocalizedError { var errorDescription: String? { "install failed" } }
        let builder = MockHarnessBuilder(result: .success(.built(appPath: "/cache/Harness.app")))
        let controller = MockHarnessSimulatorController(installError: InstallFailed())
        let statuses = StatusRecorder()
        let presenter = makePresenter(builder: builder, controller: controller)

        await presenter.present(request, report: statuses.record)

        #expect(statuses.statuses.last?.state == .failed)
        #expect(statuses.statuses.last?.message?.contains("install failed") == true)
    }

    @Test
    func aTargetThatCannotBeResolvedIsReportedAsAFailure() async {
        let builder = MockHarnessBuilder(result: .success(.built(appPath: "/x")))
        let statuses = StatusRecorder()
        let presenter = makePresenter(
            builder: builder,
            controller: MockHarnessSimulatorController(),
            resolveTarget: { throw PlaygroundError.deviceNotFound("UDID-1") }
        )

        await presenter.present(request, report: statuses.record)

        #expect(statuses.statuses.map(\.state) == [.building, .failed])
        #expect(statuses.statuses.last?.message?.contains("UDID-1") == true)
        #expect(builder.builds.isEmpty)
    }

    // MARK: - Helpers

    private func makePresenter(
        builder: MockHarnessBuilder,
        controller: MockHarnessSimulatorController,
        resolveTarget: (@Sendable () throws -> HarnessTarget)? = nil,
        importDiagnostics: @escaping @Sendable (String, HarnessTarget) -> [PlaygroundDiagnostic] = { _, _ in [] },
        output: @escaping @Sendable (String) -> Void = { _ in }
    ) -> PlaygroundComponentPresenter {
        let target = target
        return PlaygroundComponentPresenter(
            builder: builder,
            controller: controller,
            resolveTarget: resolveTarget ?? { target },
            importDiagnostics: importDiagnostics,
            output: output
        )
    }
}
