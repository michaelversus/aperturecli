import Foundation
import Security

enum PlaygroundTokenGenerator {
    /// A fresh random token, 32 bytes as 64 hex characters, for one run of the playground command.
    static func make() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw PlaygroundError.commandFailed("Could not generate a random token.")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
