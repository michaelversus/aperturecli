extension PlaygroundComponentRequest {
    /// A very simple component, so the whole path (request, build, launch, stream, tap) can be proven without the app.
    static let mock = PlaygroundComponentRequest(
        id: "mock-counter",
        kind: .swiftUIView,
        source: """
        import SwiftUI

        struct CounterView: View {
            @State private var count = 0

            var body: some View {
                VStack(spacing: 16) {
                    Text("Count: \\(count)").font(.largeTitle)
                    Button("Increment") { count += 1 }.buttonStyle(.borderedProminent)
                }
            }
        }
        """,
        entry: "CounterView()",
        snapshotName: "mock-counter",
        theme: .light
    )
}
