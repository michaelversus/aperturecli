import Foundation

/// What the playground can observe from outside the simulator to decide whether input landed.
protocol SimulatorScreenObserving: Sendable {
    /// A digest of the current screen contents; equal digests mean an unchanged screen.
    func screenDigest() async throws -> String
    /// Guest log lines reporting that the HID daemon dropped events since `start`.
    func droppedEventLogLines(since start: Date) async throws -> [String]
}
