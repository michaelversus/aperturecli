/// Performs the gestures clients stream, one finger at a time, and lifts it if its client goes away mid-gesture.
actor PlaygroundTouchRunner {
    private struct Contact {
        let owner: ObjectIdentifier
        var point: NormalizedPoint
    }

    private let session: any SimulatorSession
    private let output: @Sendable (String) -> Void
    private var contact: Contact?

    init(session: any SimulatorSession, output: @escaping @Sendable (String) -> Void) {
        self.session = session
        self.output = output
    }

    /// A move or end from a client that did not start the current gesture is ignored.
    func run(_ touch: PlaygroundTouch, from owner: ObjectIdentifier) async {
        switch touch.phase {
        case .start:
            if contact != nil { await lift() }
            contact = Contact(owner: owner, point: touch.point)
            await send(touch)
        case .position, .end:
            guard let current = contact, current.owner == owner else { return }
            contact?.point = touch.point
            if touch.phase == .end { contact = nil }
            await send(touch)
        }
    }

    /// Lifts the finger if `owner` still holds it, so a closed connection cannot leave it pressed.
    func release(owner: ObjectIdentifier) async {
        guard contact?.owner == owner else { return }
        await lift()
    }

    private func lift() async {
        guard let current = contact else { return }
        contact = nil
        await send(PlaygroundTouch(phase: .end, point: current.point))
    }

    private func send(_ touch: PlaygroundTouch) async {
        do {
            try await session.touch(touch.phase, at: touch.point)
        } catch {
            contact = nil
            output("Touch failed: \(error.localizedDescription)")
        }
    }
}
