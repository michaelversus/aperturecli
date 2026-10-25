/// What the harness is built against: the simulator SDK, and the iOS version of the simulator it will run on.
struct HarnessTarget: Equatable, Sendable {
    let sdkPath: String
    let iOSVersion: String
}
