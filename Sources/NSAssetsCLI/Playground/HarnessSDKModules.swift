/// Which modules the simulator SDK ships, so imports of anything else can be refused with a clear message.
struct HarnessSDKModules {
    let sdkPath: String
    let fileSystem: FileSystemProvider

    func isSystemModule(_ name: String) -> Bool {
        fileSystem.fileExists(atPath: "\(sdkPath)/System/Library/Frameworks/\(name).framework")
            || fileSystem.fileExists(atPath: "\(sdkPath)/usr/lib/swift/\(name).swiftmodule")
    }
}
