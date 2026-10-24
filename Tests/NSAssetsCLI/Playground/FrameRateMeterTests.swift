import Foundation
import Testing
@testable import NSAssetsCLI

struct FrameRateMeterTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test
    func computesFramesPerSecondFromTheFirstToTheLastFrame() {
        var meter = FrameRateMeter()
        for index in 0...30 {
            meter.record(frameAt: start.addingTimeInterval(Double(index) / 30))
        }

        let report = meter.report()

        #expect(report.frameCount == 31)
        #expect(abs(report.framesPerSecond - 30) < 0.001)
    }

    @Test
    func reportsTheSlowestGapBetweenFrames() {
        var meter = FrameRateMeter()
        meter.record(frameAt: start)
        meter.record(frameAt: start.addingTimeInterval(0.01))
        meter.record(frameAt: start.addingTimeInterval(0.26))

        #expect(abs(meter.report().longestGap - 0.25) < 0.001)
    }

    @Test
    func anEmptyMeterReportsZeroes() {
        let report = FrameRateMeter().report()

        #expect(report.frameCount == 0)
        #expect(report.framesPerSecond == 0)
        #expect(report.longestGap == 0)
    }
}
