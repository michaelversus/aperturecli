enum SimulatorProbeClassifier {
    /// First CoreSimulator build that ships the DTUHID daemon the playground sends input through.
    static let firstDTUHIDCoreSimulatorVersion = "1155.4"

    static func classify(_ facts: SimulatorProbeFacts) -> SimulatorProbeResult {
        var issues: [SimulatorProbeIssue] = []

        if !facts.coreSimulatorFound {
            issues.append(.coreSimulatorNotFound)
        } else if !facts.serviceContextClassPresent {
            issues.append(.serviceContextClassMissing)
        }
        if !facts.simulatorKitFound {
            issues.append(.simulatorKitNotFound)
        }
        if !facts.xpcSymbolsPresent {
            issues.append(.xpcSymbolsMissing)
        }
        if let version = facts.coreSimulatorVersion,
           NumericVersion.compare(version, firstDTUHIDCoreSimulatorVersion) == .orderedAscending {
            issues.append(.coreSimulatorTooOld(minimum: firstDTUHIDCoreSimulatorVersion))
        }
        if facts.framebufferPortFound == false {
            issues.append(.noFramebufferPort)
        }
        if facts.surfaceMatchesNativeSize == false {
            issues.append(.surfaceSizeMismatch)
        }
        if let displayCount = facts.displayCount, displayCount > 1 {
            issues.append(.multipleDisplays)
        }
        if facts.deviceHubFlagActive == true {
            issues.append(.deviceHubAttached(repairCommand: repairCommand(udid: facts.simulatorUDID)))
        }

        return SimulatorProbeResult(
            status: status(for: issues),
            xcodeVersion: facts.xcodeVersion,
            coreSimulatorVersion: facts.coreSimulatorVersion,
            issues: issues
        )
    }

    private static func repairCommand(udid: String?) -> String {
        let device = udid ?? "<udid>"
        return "xcrun simctl spawn \(device) notifyutil -s com.apple.coredevice.dtuhidd.active 0 "
            + "&& xcrun simctl spawn \(device) launchctl kickstart -k system/com.apple.backboardd"
    }

    private static func status(for issues: [SimulatorProbeIssue]) -> SimulatorProbeStatus {
        if issues.contains(where: \.isBlocking) { return .unsupported }
        return issues.isEmpty ? .supported : .degraded
    }
}
