import Foundation

/// Takes one real frame from a booted simulator to learn whether the framebuffer works and how big it is.
enum FramebufferProbe {
    private static let firstFrameTimeout = Duration.seconds(3)

    static func run(ioClient: NSObject) async -> FramebufferProbeFacts {
        let source = FramebufferFrameSource(ioClient: ioClient)
        let frame = await firstFrame(from: source)
        return FramebufferProbeFacts(
            portFound: frame != nil,
            displayCount: frame == nil ? 0 : source.nativeDisplayCount(),
            frameWidthInPixels: frame?.widthInPixels,
            frameHeightInPixels: frame?.heightInPixels
        )
    }

    private static func firstFrame(from source: FramebufferFrameSource) async -> SimulatorFrame? {
        await withTaskGroup(of: SimulatorFrame?.self) { group in
            group.addTask {
                // A thrown error means there is no framebuffer port; either way there is no first frame.
                try? await source.frames().first { !$0.isReplay }
            }
            group.addTask {
                try? await Task.sleep(for: firstFrameTimeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
