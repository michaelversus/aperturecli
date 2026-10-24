/// A text message from a connected client: a hello that names its protocol, or a tap.
struct PlaygroundClientMessage: Decodable, Equatable {
    let type: String
    let protocolVersion: Int?
    let horizontal: Double?
    let vertical: Double?

    enum CodingKeys: String, CodingKey {
        case type
        case protocolVersion
        case horizontal = "x"
        case vertical = "y"
    }

    /// The tap this message asks for, or `nil` for anything else, including taps outside the screen.
    var tapPoint: NormalizedPoint? {
        guard type == "tap", let horizontal, let vertical,
              (0...1).contains(horizontal), (0...1).contains(vertical)
        else { return nil }
        return NormalizedPoint(horizontal: horizontal, vertical: vertical)
    }
}
