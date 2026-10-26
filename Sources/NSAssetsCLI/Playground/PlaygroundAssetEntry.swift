import Foundation

/// One asset catalog entry the app asks the harness to carry, so `Image("logo")` and `Color("brand")` resolve.
struct PlaygroundAssetEntry: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case imageset
        case colorset
    }

    let catalog: String
    let kind: Kind
    /// The `.imageset` or `.colorset` folder inside the project's catalog.
    let path: String

    /// What the component looks the entry up by: the folder's name without its extension.
    var name: String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}
