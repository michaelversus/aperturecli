import Testing
@testable import NSAssetsCLI

struct PlaygroundMockComponentTests {
    @Test
    func theMockIsAVerySimpleSelfContainedSwiftUIView() {
        let mock = PlaygroundComponentRequest.mock

        #expect(mock.kind == .swiftUIView)
        #expect(mock.source.contains("Button"))
        #expect(mock.source.contains("Text"))
        #expect(mock.entry == "CounterView()")
        let imports = HarnessImportChecker(isSystemModule: { $0 == "SwiftUI" }).diagnostics(forSource: mock.source)
        #expect(imports.isEmpty)
    }

    @Test
    func theMockCountsTapsOnItsButton() {
        #expect(PlaygroundComponentRequest.mock.source.contains("count += 1"))
    }
}
