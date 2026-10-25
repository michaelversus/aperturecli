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

    @Test(arguments: [("start", SimulatorTouchPhase.start), ("move", .position), ("end", .end)])
    func aTouchInsideTheScreenCarriesItsPhaseAndPoint(name: String, phase: SimulatorTouchPhase) throws {
        let message = try decode(#"{"type":"touch","phase":"\#(name)","x":0.25,"y":0.75}"#)

        let point = NormalizedPoint(horizontal: 0.25, vertical: 0.75)
        #expect(message.touch == PlaygroundTouch(phase: phase, point: point))
    }

    @Test(arguments: [
        #"{"type":"touch","phase":"start","x":1.5,"y":0.5}"#,
        #"{"type":"touch","phase":"sideways","x":0.5,"y":0.5}"#,
        #"{"type":"touch","x":0.5,"y":0.5}"#,
        #"{"type":"tap","x":0.5,"y":0.5}"#
    ])
    func anythingElseIsNotATouch(json: String) throws {
        #expect(try decode(json).touch == nil)
    }

    @Test(arguments: [("down", true), ("up", false)])
    func aKnownKeyCarriesItsUsageAndDirection(name: String, isDown: Bool) throws {
        let message = try decode(#"{"type":"key","code":"KeyA","phase":"\#(name)"}"#)

        #expect(message.keyPress == PlaygroundKeyPress(usage: 0x04, isDown: isDown))
    }

    @Test(arguments: [
        #"{"type":"key","code":"F24","phase":"down"}"#,
        #"{"type":"key","code":"KeyA","phase":"hold"}"#,
        #"{"type":"key","phase":"down"}"#,
        #"{"type":"tap","code":"KeyA","phase":"down"}"#
    ])
    func anythingElseIsNotAKeyPress(json: String) throws {
        #expect(try decode(json).keyPress == nil)
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
