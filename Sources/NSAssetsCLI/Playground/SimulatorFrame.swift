import Foundation

struct SimulatorFrame: Sendable, Equatable {
    let jpegData: Data
    let widthInPixels: Int
    let heightInPixels: Int
    let timestamp: Date
    /// True for a repeat of the previous frame sent so a static screen does not look stalled.
    let isReplay: Bool
}
