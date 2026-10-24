import Foundation

struct FrameRateMeter {
    private var timestamps: [Date] = []

    mutating func record(frameAt timestamp: Date) {
        timestamps.append(timestamp)
    }

    func report() -> FrameRateReport {
        guard let first = timestamps.first, let last = timestamps.last, timestamps.count > 1 else {
            return FrameRateReport(frameCount: timestamps.count, framesPerSecond: 0, longestGap: 0)
        }
        let span = last.timeIntervalSince(first)
        let gaps = zip(timestamps, timestamps.dropFirst()).map { $1.timeIntervalSince($0) }
        return FrameRateReport(
            frameCount: timestamps.count,
            framesPerSecond: span > 0 ? Double(timestamps.count - 1) / span : 0,
            longestGap: gaps.max() ?? 0
        )
    }
}
