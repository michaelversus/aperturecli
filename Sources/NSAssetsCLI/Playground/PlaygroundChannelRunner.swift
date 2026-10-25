import Foundation

/// Runs the channel for one simulator: starts the server, announces it to the app, and serves until the surrounding
/// task is cancelled. The hidden debug viewer runs alongside when one is given.
struct PlaygroundChannelRunner {
    let server: PlaygroundChannelServer
    let token: String
    let simulatorUDID: String
    let workingDirectory: String
    let poster: any DistributedNotificationPosting & Sendable
    let debugViewer: PlaygroundDebugViewer?
    let onReady: @Sendable (UInt16) -> Void
    let onDebugViewerReady: @Sendable (UInt16) -> Void

    func run() async throws {
        let port = try await server.start()
        if let debugViewer {
            let viewerPort = try await debugViewer.start(webSocketPort: port, token: token)
            await server.allow(origin: PlaygroundDebugViewer.origin(port: viewerPort))
            onDebugViewerReady(viewerPort)
        }
        let announcement = PlaygroundAnnouncement(
            port: port,
            token: token,
            simulatorUDID: simulatorUDID,
            workingDirectory: workingDirectory
        )
        poster.post(name: PlaygroundChannel.notificationName, userInfo: announcement.userInfo)
        onReady(port)

        await waitUntilCancelled()
        await debugViewer?.stop()
        await server.stop()
    }
}
