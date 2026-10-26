import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundComponentRequestHandlerTests {
    private let json = """
    {"type":"showComponent","id":"req-1","kind":"swiftUIView","source":"import SwiftUI",
     "entry":"A()","snapshotName":"populated","theme":"dark"}
    """

    @Test
    func aValidRequestIsPresentedAndItsStatusesAreReplied() async {
        let presenter = MockComponentPresenter()
        let replies = StatusRecorder()
        let handler = PlaygroundComponentRequestHandler(presenter: presenter)

        handler.handle(Data(json.utf8), reply: replies.record)

        #expect(await waitUntil { replies.statuses.count == 2 })
        #expect(replies.statuses.map(\.state) == [.building, .ready])
        #expect(presenter.requests.first?.id == "req-1")
    }

    @Test
    func aMalformedRequestIsRepliedToWithItsIDWhenItHasOne() async {
        let handler = PlaygroundComponentRequestHandler(presenter: MockComponentPresenter())
        let replies = StatusRecorder()

        handler.handle(Data(#"{"type":"showComponent","id":"req-9"}"#.utf8), reply: replies.record)

        #expect(replies.statuses.first?.id == "req-9")
        #expect(replies.statuses.first?.state == .failed)
        #expect(replies.statuses.first?.message?.contains("malformed") == true)
    }

    @Test
    func aMalformedRequestWithoutAnIDIsRepliedToWithAnEmptyOne() {
        let handler = PlaygroundComponentRequestHandler(presenter: MockComponentPresenter())
        let replies = StatusRecorder()

        handler.handle(Data("not json".utf8), reply: replies.record)

        #expect(replies.statuses.first?.id == "")
        #expect(replies.statuses.first?.state == .failed)
    }

    @Test
    func aClearRequestIsClearedAndRepliedToWithItsID() async {
        let presenter = MockComponentPresenter()
        let replies = StatusRecorder()
        let handler = PlaygroundComponentRequestHandler(presenter: presenter)

        handler.handleClear(Data(#"{"type":"clearComponent","id":"c-1","extra":1}"#.utf8), reply: replies.record)

        #expect(await waitUntil { replies.statuses.count == 1 })
        #expect(replies.statuses == [PlaygroundComponentStatus(id: "c-1", state: .cleared)])
        #expect(presenter.clears == ["c-1"])
    }

    @Test
    func aClearRequestWithoutAnIDIsRepliedToWithAFailure() {
        let presenter = MockComponentPresenter()
        let replies = StatusRecorder()
        let handler = PlaygroundComponentRequestHandler(presenter: presenter)

        handler.handleClear(Data(#"{"type":"clearComponent"}"#.utf8), reply: replies.record)

        #expect(replies.statuses.first?.state == .failed)
        #expect(presenter.clears.isEmpty)
    }

    @Test
    func withoutAPresenterAClearRequestIsRepliedToWithAFailure() {
        let handler = PlaygroundComponentRequestHandler(presenter: nil)
        let replies = StatusRecorder()

        handler.handleClear(Data(#"{"type":"clearComponent","id":"c-1"}"#.utf8), reply: replies.record)

        #expect(replies.statuses.first?.state == .failed)
        #expect(replies.statuses.first?.id == "c-1")
    }

    @Test
    func withoutAPresenterTheRequestIsRepliedToWithAFailure() {
        let handler = PlaygroundComponentRequestHandler(presenter: nil)
        let replies = StatusRecorder()

        handler.handle(Data(json.utf8), reply: replies.record)

        #expect(replies.statuses.first?.state == .failed)
        #expect(replies.statuses.first?.id == "req-1")
    }

    @Test
    func requestsFromTheChannelAndDirectPresentationsNeverOverlap() async {
        let presenter = MockComponentPresenter(statuses: [.ready], duration: .milliseconds(120))
        let handler = PlaygroundComponentRequestHandler(presenter: presenter)

        handler.handle(Data(json.utf8), reply: { _ in })
        handler.present(.mock, reply: { _ in })
        handler.handle(Data(json.utf8), reply: { _ in })

        #expect(await waitUntil { presenter.requests.count == 3 })
        try? await Task.sleep(for: .milliseconds(300))
        #expect(!presenter.didOverlap)
    }
}
