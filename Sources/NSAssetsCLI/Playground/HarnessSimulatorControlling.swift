protocol HarnessSimulatorControlling: Sendable {
    func setAppearance(_ theme: PlaygroundTheme) throws
    func install(appPath: String) throws
    /// Stops the harness if it is running, then launches the freshly installed one.
    func relaunch() throws
    /// Stops the harness, which returns the simulator to the home screen. Succeeds when it was not running.
    func clear() throws
}
