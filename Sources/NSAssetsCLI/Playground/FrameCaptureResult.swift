import Foundation

struct FrameCaptureResult {
    let report: FrameRateReport
    let averageJPEGKilobytes: Double
    let sizeInPixels: String

    var summary: String {
        String(
            format: "%d frames, %.1f fps, longest gap %.0f ms, avg %.0f KB JPEG, %@",
            report.frameCount, report.framesPerSecond, report.longestGap * 1000,
            averageJPEGKilobytes, sizeInPixels
        )
    }
}
