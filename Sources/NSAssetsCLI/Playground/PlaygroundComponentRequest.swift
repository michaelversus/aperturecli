/// What NSAssets Studio sends to show one component: self-contained source and one expression that builds it.
struct PlaygroundComponentRequest: Codable, Equatable, Sendable {
    let id: String
    let kind: PlaygroundComponentKind
    let source: String
    let entry: String
    let snapshotName: String
    let theme: PlaygroundTheme
    /// Catalog entries the component looks up by name; absent when it uses none.
    var assets: [PlaygroundAssetEntry]?
}
