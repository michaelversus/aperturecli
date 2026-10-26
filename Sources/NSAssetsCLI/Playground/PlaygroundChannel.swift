import Foundation

/// The names and numbers both ends of the playground channel must agree on.
enum PlaygroundChannel {
    /// Bumped whenever the messages change in a way an older app or CLI cannot understand.
    static let protocolVersion = 1
    static let notificationName = Notification.Name("app.nsbuilder.nsassets.playground.ready")
    /// Posted by the app to ask a running `serve` to announce itself again.
    static let discoverNotificationName = Notification.Name("app.nsbuilder.nsassets.playground.discover")

    private static let subprotocolPrefix = "nsassets-playground."

    /// The WebSocket subprotocol that carries the token, so a connection can be refused during the handshake.
    static func subprotocol(token: String) -> String {
        subprotocolPrefix + token
    }
}
