import Testing
@testable import NSAssetsCLI

struct SimulatorProbeClassifierTests {
    @Test
    func healthyModernMachineIsSupported() {
        let result = SimulatorProbeClassifier.classify(makeFacts())

        #expect(result.status == .supported)
        #expect(result.issues.isEmpty)
        #expect(result.xcodeVersion == "27.1")
        #expect(result.coreSimulatorVersion == "1155.4")
    }

    @Test
    func missingCoreSimulatorIsUnsupported() {
        let result = SimulatorProbeClassifier.classify(
            makeFacts(coreSimulatorVersion: nil, coreSimulatorFound: false)
        )

        #expect(result.status == .unsupported)
        #expect(result.issues.contains(.coreSimulatorNotFound))
    }

    @Test
    func missingSimulatorKitIsUnsupportedBecauseFramesNeedIt() {
        let result = SimulatorProbeClassifier.classify(makeFacts(simulatorKitFound: false))

        #expect(result.status == .unsupported)
        #expect(result.issues.contains(.simulatorKitNotFound))
    }

    @Test
    func aMissingServiceContextClassIsReportedAsAnIssue() {
        let result = SimulatorProbeClassifier.classify(makeFacts(serviceContextClassPresent: false))

        #expect(result.status == .unsupported)
        #expect(result.issues.contains(.serviceContextClassMissing))
    }

    @Test
    func missingXPCSymbolsAreUnsupportedBecauseDTUHIDIsTheOnlyInputPath() {
        let result = SimulatorProbeClassifier.classify(makeFacts(xpcSymbolsPresent: false))

        #expect(result.status == .unsupported)
        #expect(result.issues.contains(.xpcSymbolsMissing))
    }

    @Test
    func aCoreSimulatorOlderThanTheDTUHIDDaemonIsUnsupported() {
        let result = SimulatorProbeClassifier.classify(makeFacts(coreSimulatorVersion: "1155.3"))

        #expect(result.status == .unsupported)
        #expect(result.issues.contains(.coreSimulatorTooOld(minimum: "1155.4")))
    }

    @Test
    func theVersionGateComparesNumerically() {
        let result = SimulatorProbeClassifier.classify(makeFacts(coreSimulatorVersion: "1155.10"))

        #expect(result.status == .supported)
    }

    @Test
    func anUnreadableCoreSimulatorVersionDoesNotBlock() {
        let result = SimulatorProbeClassifier.classify(makeFacts(coreSimulatorVersion: nil))

        #expect(result.status == .supported)
    }

    @Test
    func missingFramebufferPortIsUnsupported() {
        let result = SimulatorProbeClassifier.classify(makeFacts(framebufferPortFound: false))

        #expect(result.status == .unsupported)
        #expect(result.issues.contains(.noFramebufferPort))
    }

    @Test
    func deviceHubFlagIsDegradedAndCarriesTheRepairCommand() {
        let result = SimulatorProbeClassifier.classify(makeFacts(deviceHubFlagActive: true))

        #expect(result.status == .degraded)
        let repair = "xcrun simctl spawn UDID-1 notifyutil -s com.apple.coredevice.dtuhidd.active 0 "
            + "&& xcrun simctl spawn UDID-1 launchctl kickstart -k system/com.apple.backboardd"
        #expect(result.issues.contains(.deviceHubAttached(repairCommand: repair)))
    }

    @Test
    func surfaceSizeMismatchIsDegraded() {
        let result = SimulatorProbeClassifier.classify(makeFacts(surfaceMatchesNativeSize: false))

        #expect(result.status == .degraded)
        #expect(result.issues.contains(.surfaceSizeMismatch))
    }

    @Test
    func multipleDisplaysAreDegraded() {
        let result = SimulatorProbeClassifier.classify(makeFacts(displayCount: 2))

        #expect(result.status == .degraded)
        #expect(result.issues.contains(.multipleDisplays))
    }

    @Test
    func uncheckedRuntimeFactsDoNotRaiseIssues() {
        let result = SimulatorProbeClassifier.classify(
            makeFacts(
                simulatorUDID: nil,
                framebufferPortFound: nil,
                surfaceMatchesNativeSize: nil,
                deviceHubFlagActive: nil,
                displayCount: nil
            )
        )

        #expect(result.status == .supported)
    }
}

private func makeFacts(
    xcodeVersion: String = "27.1",
    coreSimulatorVersion: String? = "1155.4",
    coreSimulatorFound: Bool = true,
    simulatorKitFound: Bool = true,
    serviceContextClassPresent: Bool = true,
    xpcSymbolsPresent: Bool = true,
    simulatorUDID: String? = "UDID-1",
    framebufferPortFound: Bool? = true,
    surfaceMatchesNativeSize: Bool? = true,
    deviceHubFlagActive: Bool? = false,
    displayCount: Int? = 1
) -> SimulatorProbeFacts {
    SimulatorProbeFacts(
        xcodeVersion: xcodeVersion,
        coreSimulatorVersion: coreSimulatorVersion,
        coreSimulatorFound: coreSimulatorFound,
        simulatorKitFound: simulatorKitFound,
        serviceContextClassPresent: serviceContextClassPresent,
        xpcSymbolsPresent: xpcSymbolsPresent,
        simulatorUDID: simulatorUDID,
        framebufferPortFound: framebufferPortFound,
        surfaceMatchesNativeSize: surfaceMatchesNativeSize,
        deviceHubFlagActive: deviceHubFlagActive,
        displayCount: displayCount
    )
}
