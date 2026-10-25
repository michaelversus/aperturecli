/// Sends the input messages of clients (taps, gestures, keys, buttons) to the session one after another, in the
/// order they arrived, because verifying a tap compares screens before and after it.
struct PlaygroundInputRouter: Sendable {
    private let tapRunner: PlaygroundTapRunner
    private let touchRunner: PlaygroundTouchRunner
    private let keyboardRunner: PlaygroundKeyboardRunner
    private let buttonRunner: PlaygroundButtonRunner
    private let queue = SerialTaskQueue()

    init(session: any SimulatorSession, verifier: SimulatorTapVerifier?, output: @escaping @Sendable (String) -> Void) {
        tapRunner = PlaygroundTapRunner(session: session, verifier: verifier, output: output)
        touchRunner = PlaygroundTouchRunner(session: session, output: output)
        keyboardRunner = PlaygroundKeyboardRunner(session: session, output: output)
        buttonRunner = PlaygroundButtonRunner(session: session, output: output)
    }

    /// Queues what the message asks for. Anything that is not an input, or is not valid, is ignored.
    func route(_ message: PlaygroundClientMessage, from owner: ObjectIdentifier) {
        let tapRunner = tapRunner
        let touchRunner = touchRunner
        let keyboardRunner = keyboardRunner
        let buttonRunner = buttonRunner
        if let touch = message.touch {
            queue.enqueue { await touchRunner.run(touch, from: owner) }
        } else if let button = message.buttonPress {
            queue.enqueue { await buttonRunner.run(button) }
        } else if let press = message.keyPress {
            queue.enqueue { await keyboardRunner.run(press, from: owner) }
        } else if let point = message.tapPoint {
            queue.enqueue { await tapRunner.run(point) }
        }
    }

    /// Lifts the finger and releases the keys a disconnected client still holds.
    func release(owner: ObjectIdentifier) {
        let touchRunner = touchRunner
        let keyboardRunner = keyboardRunner
        queue.enqueue {
            await touchRunner.release(owner: owner)
            await keyboardRunner.release(owner: owner)
        }
    }
}
