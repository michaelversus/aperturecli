/// Presses a hardware button for a client, and reports a failure to the terminal.
struct PlaygroundButtonRunner: Sendable {
    let session: any SimulatorSession
    let output: @Sendable (String) -> Void

    func run(_ button: SimulatorHardwareButton) async {
        do {
            try await session.press(button)
        } catch {
            output("Button failed: \(error.localizedDescription)")
        }
    }
}
