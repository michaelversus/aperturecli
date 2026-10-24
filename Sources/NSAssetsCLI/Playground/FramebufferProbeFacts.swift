/// What a short look at a booted simulator's framebuffer showed.
struct FramebufferProbeFacts: Sendable, Equatable {
    let portFound: Bool
    let displayCount: Int
    let frameWidthInPixels: Int?
    let frameHeightInPixels: Int?
}
