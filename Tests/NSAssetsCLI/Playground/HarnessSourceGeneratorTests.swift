import Testing
@testable import NSAssetsCLI

struct HarnessSourceGeneratorTests {
    @Test
    func aSwiftUIEntryReturnsTheExpressionAsTheView() {
        let entry = HarnessSourceGenerator.entry(kind: .swiftUIView, expression: "CounterView()")

        #expect(entry.text.contains("import SwiftUI"))
        #expect(entry.text.contains("static func make() -> some View"))
        #expect(entry.text.contains("CounterView()"))
        #expect(!entry.text.contains("UIViewRepresentable"))
    }

    @Test
    func aUIKitViewIsHostedInAViewRepresentable() {
        let entry = HarnessSourceGenerator.entry(kind: .uiKitView, expression: "BadgeView()")

        #expect(entry.text.contains("import UIKit"))
        #expect(entry.text.contains("UIViewRepresentable"))
        #expect(entry.text.contains("func makeUIView(context: Context) -> UIView"))
        #expect(entry.text.contains("BadgeView()"))
    }

    @Test
    func aUIKitViewControllerIsHostedInAViewControllerRepresentable() {
        let entry = HarnessSourceGenerator.entry(kind: .uiKitViewController, expression: "DetailViewController()")

        #expect(entry.text.contains("UIViewControllerRepresentable"))
        #expect(entry.text.contains("func makeUIViewController(context: Context) -> UIViewController"))
        #expect(entry.text.contains("DetailViewController()"))
    }

    @Test(arguments: [PlaygroundComponentKind.swiftUIView, .uiKitView, .uiKitViewController])
    func theEntryFirstLineIsWhereTheExpressionStarts(kind: PlaygroundComponentKind) {
        let entry = HarnessSourceGenerator.entry(kind: kind, expression: "UniqueExpressionMarker()")

        let lines = entry.text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[entry.firstExpressionLine - 1].contains("UniqueExpressionMarker()"))
    }

    @Test
    func aMultiLineExpressionStartsOnTheReportedLine() {
        let entry = HarnessSourceGenerator.entry(kind: .swiftUIView, expression: "Group {\n    Text(\"A\")\n}")

        let lines = entry.text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[entry.firstExpressionLine - 1].contains("Group {"))
    }

    @Test
    func theAppSourceIsASwiftUIAppThatShowsTheEntry() {
        #expect(HarnessSourceGenerator.appSource.contains("@main"))
        #expect(HarnessSourceGenerator.appSource.contains("WindowGroup"))
        #expect(HarnessSourceGenerator.appSource.contains("PlaygroundEntry.make()"))
    }

    @Test
    func theInfoPlistNamesTheBundleAndTheMinimumOS() {
        let plist = HarnessSourceGenerator.infoPlist(minimumOSVersion: "27.0")

        #expect(plist.contains("<string>\(HarnessSourceGenerator.bundleIdentifier)</string>"))
        #expect(plist.contains("<key>MinimumOSVersion</key><string>27.0</string>"))
        #expect(plist.contains("iPhoneSimulator"))
    }
}
