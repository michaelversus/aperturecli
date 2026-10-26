import Foundation

/// The facts NSAssets Studio reads from `nsassets-artifacts/cli.json` before any connection exists.
struct CLIMarker: Codable, Equatable {
    let cliVersion: String
    let protocolVersion: Int
    let updatedAt: String
}
