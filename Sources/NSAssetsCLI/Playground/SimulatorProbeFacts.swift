/// What the machine reported when inspected. `nil` means "not checked", for facts that
/// can only be known with a booted simulator.
struct SimulatorProbeFacts: Sendable, Equatable {
    let xcodeVersion: String
    let coreSimulatorVersion: String?
    let coreSimulatorFound: Bool
    let simulatorKitFound: Bool
    /// Private classes the playground needs that did not load; empty when all are present.
    let missingPrivateClasses: [String]
    let xpcSymbolsPresent: Bool
    let simulatorUDID: String?
    let framebufferPortFound: Bool?
    let surfaceMatchesNativeSize: Bool?
    let deviceHubFlagActive: Bool?
    let displayCount: Int?

    /// The same facts with the framebuffer ones filled in from a look at a booted simulator.
    func withFramebuffer(
        portFound: Bool,
        surfaceMatchesNativeSize: Bool?,
        displayCount: Int
    ) -> SimulatorProbeFacts {
        SimulatorProbeFacts(
            xcodeVersion: xcodeVersion,
            coreSimulatorVersion: coreSimulatorVersion,
            coreSimulatorFound: coreSimulatorFound,
            simulatorKitFound: simulatorKitFound,
            missingPrivateClasses: missingPrivateClasses,
            xpcSymbolsPresent: xpcSymbolsPresent,
            simulatorUDID: simulatorUDID,
            framebufferPortFound: portFound,
            surfaceMatchesNativeSize: surfaceMatchesNativeSize,
            deviceHubFlagActive: deviceHubFlagActive,
            displayCount: displayCount
        )
    }
}
