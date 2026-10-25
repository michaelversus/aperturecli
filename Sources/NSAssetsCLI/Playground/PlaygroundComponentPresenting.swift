protocol PlaygroundComponentPresenting: Sendable {
    /// Builds and launches the component, reporting `building`, then `ready` or `failed` as it goes.
    func present(
        _ request: PlaygroundComponentRequest,
        report: @Sendable (PlaygroundComponentStatus) -> Void
    ) async
}
