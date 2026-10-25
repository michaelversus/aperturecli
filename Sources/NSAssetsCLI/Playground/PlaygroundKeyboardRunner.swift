/// Performs the key presses clients stream, and releases the keys a client still holds when it goes away.
actor PlaygroundKeyboardRunner {
    private let session: any SimulatorSession
    private let output: @Sendable (String) -> Void
    /// Held keys in press order, with the client that pressed each.
    private var held: [(usage: UInt64, owner: ObjectIdentifier)] = []

    init(session: any SimulatorSession, output: @escaping @Sendable (String) -> Void) {
        self.session = session
        self.output = output
    }

    /// A key already down (a browser's auto-repeat) is not pressed again, and only the client that pressed a key
    /// can release it.
    func run(_ press: PlaygroundKeyPress, from owner: ObjectIdentifier) async {
        if press.isDown {
            guard !held.contains(where: { $0.usage == press.usage }) else { return }
            held.append((press.usage, owner))
        } else {
            guard let index = held.firstIndex(where: { $0.usage == press.usage && $0.owner == owner }) else { return }
            held.remove(at: index)
        }
        await send(press)
    }

    func release(owner: ObjectIdentifier) async {
        let mine = held.filter { $0.owner == owner }
        held.removeAll { $0.owner == owner }
        for key in mine.reversed() {
            await send(PlaygroundKeyPress(usage: key.usage, isDown: false))
        }
    }

    private func send(_ press: PlaygroundKeyPress) async {
        do {
            try await session.key(usage: press.usage, isDown: press.isDown)
        } catch {
            output("Key failed: \(error.localizedDescription)")
        }
    }
}
