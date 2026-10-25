import Foundation

/// What the CLI tells NSAssets Studio through the distributed notification so it can connect.
struct PlaygroundAnnouncement: Sendable, Equatable {
    let port: UInt16
    let token: String
    let simulatorUDID: String
    let workingDirectory: String

    var userInfo: [AnyHashable: Any] {
        [
            "port": Int(port),
            "token": token,
            "cliVersion": version,
            "protocolVersion": PlaygroundChannel.protocolVersion,
            "simulatorUDID": simulatorUDID,
            "workingDirectory": workingDirectory
        ]
    }
}
