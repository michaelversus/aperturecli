/// A point in the simulator screen with both axes in 0...1 and the origin at the top left.
struct NormalizedPoint: Sendable, Equatable {
    let horizontal: Double
    let vertical: Double
}
