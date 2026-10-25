import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundClientMessageTests {
    @Test
    func aTapInsideTheScreenIsATapPoint() throws {
        let message = try decode(#"{"type":"tap","x":0.25,"y":1}"#)

        #expect(message.tapPoint == NormalizedPoint(horizontal: 0.25, vertical: 1))
    }

    @Test(arguments: [
        #"{"type":"tap","x":1.5,"y":0.5}"#,
        #"{"type":"tap","x":0.5,"y":-0.1}"#,
        #"{"type":"tap","x":0.5}"#,
        #"{"type":"hello","protocolVersion":1}"#
    ])
    func anythingElseIsNotATapPoint(json: String) throws {
        #expect(try decode(json).tapPoint == nil)
    }

    @Test
    func theServerMessagesNameTheVersionsInvolved() {
        #expect(PlaygroundServerMessage.hello().protocolVersion == PlaygroundChannel.protocolVersion)
        let incompatible = PlaygroundServerMessage.incompatible(clientProtocolVersion: 7)
        #expect(incompatible.supportedProtocolVersion == PlaygroundChannel.protocolVersion)
        #expect(incompatible.reason?.contains("7") == true)
    }

    private func decode(_ json: String) throws -> PlaygroundClientMessage {
        try JSONDecoder().decode(PlaygroundClientMessage.self, from: Data(json.utf8))
    }
}
