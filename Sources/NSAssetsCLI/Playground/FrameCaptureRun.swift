import Foundation

/// Consumes a session's frames for a fixed time and measures them, ignoring idle-floor replays.
struct FrameCaptureRun {
    let seconds: Int
    let saveFirstFramePath: String?

    func run(on session: any SimulatorSession) async throws -> FrameCaptureResult {
        let seconds = seconds
        let saveFirstFramePath = saveFirstFramePath
        return try await withThrowingTaskGroup(of: FrameCaptureResult?.self) { group in
            group.addTask {
                var meter = FrameRateMeter()
                var totalBytes = 0
                var size = "no frames"
                var savedFirst = false
                for try await frame in session.frames() where !frame.isReplay {
                    meter.record(frameAt: frame.timestamp)
                    totalBytes += frame.jpegData.count
                    size = "\(frame.widthInPixels)x\(frame.heightInPixels)"
                    if !savedFirst, let path = saveFirstFramePath {
                        try frame.jpegData.write(to: URL(fileURLWithPath: path))
                        savedFirst = true
                    }
                    if Task.isCancelled { break }
                }
                let report = meter.report()
                let average = report.frameCount > 0 ? Double(totalBytes) / Double(report.frameCount) / 1024 : 0
                return FrameCaptureResult(report: report, averageJPEGKilobytes: average, sizeInPixels: size)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                return nil
            }

            var result: FrameCaptureResult?
            for try await finished in group {
                if let finished { result = finished } else { group.cancelAll() }
            }
            return result ?? FrameCaptureResult(
                report: FrameRateMeter().report(),
                averageJPEGKilobytes: 0,
                sizeInPixels: "no frames"
            )
        }
    }
}
