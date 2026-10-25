import Foundation

/// A text message from a connected client: a hello that names its protocol, a tap, a step of a gesture, or a request
/// to show a component.
struct PlaygroundClientMessage: Decodable, Equatable {
    enum Kind: String, Decodable {
        case hello
        case tap
        case touch
        case key
        case showComponent
    }

    let type: Kind
    let protocolVersion: Int?
    let horizontal: Double?
    let vertical: Double?
    let phase: String?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case type
        case protocolVersion
        case phase
        case code
        case horizontal = "x"
        case vertical = "y"
    }

    /// The tap this message asks for, or `nil` for anything else, including taps outside the screen.
    var tapPoint: NormalizedPoint? {
        type == .tap ? screenPoint : nil
    }

    /// The gesture step this message asks for, or `nil` for anything else, including steps outside the screen.
    var touch: PlaygroundTouch? {
        guard type == .touch, let screenPoint, let phase = phase.flatMap(Self.touchPhase(named:)) else { return nil }
        return PlaygroundTouch(phase: phase, point: screenPoint)
    }

    /// The key press this message asks for, or `nil` for anything else, including keys this CLI does not know.
    var keyPress: PlaygroundKeyPress? {
        guard type == .key, let usage = code.flatMap(HIDKeyboardUsage.usage(forDOMCode:)) else { return nil }
        switch phase {
        case "down": return PlaygroundKeyPress(usage: usage, isDown: true)
        case "up": return PlaygroundKeyPress(usage: usage, isDown: false)
        default: return nil
        }
    }

    private var screenPoint: NormalizedPoint? {
        guard let horizontal, let vertical, (0...1).contains(horizontal), (0...1).contains(vertical) else { return nil }
        return NormalizedPoint(horizontal: horizontal, vertical: vertical)
    }

    private static func touchPhase(named name: String) -> SimulatorTouchPhase? {
        switch name {
        case "start": .start
        case "move": .position
        case "end": .end
        default: nil
        }
    }
}
