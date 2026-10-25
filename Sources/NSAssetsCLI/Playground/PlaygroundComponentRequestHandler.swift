import Foundation

/// Turns a client's `showComponent` message into a presentation, answering problems with a failed status and running
/// one presentation at a time, since components share one harness app and one simulator.
final class PlaygroundComponentRequestHandler: Sendable {
    private struct Identity: Decodable {
        let id: String?
    }

    private let presenter: (any PlaygroundComponentPresenting)?
    private let queue = SerialTaskQueue()

    init(presenter: (any PlaygroundComponentPresenting)?) {
        self.presenter = presenter
    }

    func handle(_ text: Data, reply: @escaping @Sendable (PlaygroundComponentStatus) -> Void) {
        do {
            present(try JSONDecoder().decode(PlaygroundComponentRequest.self, from: text), reply: reply)
        } catch {
            let id = (try? JSONDecoder().decode(Identity.self, from: text))?.id ?? ""
            reply(
                PlaygroundComponentStatus(
                    id: id,
                    state: .failed,
                    message: "The component request was malformed: \(error.localizedDescription)"
                )
            )
        }
    }

    func present(
        _ request: PlaygroundComponentRequest,
        reply: @escaping @Sendable (PlaygroundComponentStatus) -> Void
    ) {
        guard let presenter else {
            reply(
                PlaygroundComponentStatus(
                    id: request.id,
                    state: .failed,
                    message: "Components are not available in this session."
                )
            )
            return
        }
        queue.enqueue { await presenter.present(request, report: reply) }
    }
}
