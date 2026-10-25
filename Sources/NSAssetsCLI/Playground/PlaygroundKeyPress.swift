/// A key going down or up, named by its USB HID keyboard usage.
struct PlaygroundKeyPress: Sendable, Equatable {
    let usage: UInt64
    let isDown: Bool
}
