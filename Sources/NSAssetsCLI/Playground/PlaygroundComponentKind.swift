/// What the component's entry expression produces, which decides how the harness presents it.
enum PlaygroundComponentKind: String, Codable, Sendable {
    case swiftUIView
    case uiKitView
    case uiKitViewController
}
