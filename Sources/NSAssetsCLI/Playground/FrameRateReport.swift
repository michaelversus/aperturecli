struct FrameRateReport: Equatable, Sendable {
    let frameCount: Int
    let framesPerSecond: Double
    /// The longest time between two consecutive frames, in seconds.
    let longestGap: Double
}
