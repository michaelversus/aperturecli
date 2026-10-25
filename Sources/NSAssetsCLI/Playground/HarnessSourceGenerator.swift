/// The harness's source files. The app source is fixed; the entry file is regenerated for every component.
enum HarnessSourceGenerator {
    static let bundleIdentifier = "app.nsbuilder.nsassets.playground.harness"
    static let appFileName = "HarnessApp.swift"
    static let componentFileName = "ComponentSource.swift"
    static let entryFileName = "PlaygroundEntry.swift"

    static let appSource = """
    import SwiftUI

    @main
    struct HarnessApp: App {
        var body: some Scene {
            WindowGroup {
                PlaygroundEntry.make()
            }
        }
    }

    """

    /// The entry expression is placed unindented and unchanged so its lines and columns stay the app's own.
    static func entry(kind: PlaygroundComponentKind, expression: String) -> HarnessEntrySource {
        let (before, after) = wrapper(for: kind)
        let text = (before + [expression] + after).joined(separator: "\n") + "\n"
        return HarnessEntrySource(text: text, firstExpressionLine: before.count + 1)
    }

    static func infoPlist(minimumOSVersion: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>CFBundleIdentifier</key><string>\(bundleIdentifier)</string>
          <key>CFBundleExecutable</key><string>Harness</string>
          <key>CFBundleName</key><string>Harness</string>
          <key>CFBundlePackageType</key><string>APPL</string>
          <key>CFBundleVersion</key><string>1</string>
          <key>CFBundleShortVersionString</key><string>1.0</string>
          <key>MinimumOSVersion</key><string>\(minimumOSVersion)</string>
          <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
          <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
          <key>UILaunchScreen</key><dict/>
        </dict></plist>

        """
    }

    /// The lines before and after the expression for each kind.
    private static func wrapper(for kind: PlaygroundComponentKind) -> (before: [String], after: [String]) {
        switch kind {
        case .swiftUIView:
            return (
                ["import SwiftUI", "", "enum PlaygroundEntry {", "    @MainActor static func make() -> some View {"],
                ["    }", "}"]
            )
        case .uiKitView:
            return (
                [
                    "import SwiftUI", "import UIKit", "",
                    "private struct PlaygroundUIKitHost: UIViewRepresentable {",
                    "    func makeUIView(context: Context) -> UIView {"
                ],
                [
                    "    }", "    func updateUIView(_ uiView: UIView, context: Context) {}", "}", "",
                    "enum PlaygroundEntry {",
                    "    @MainActor static func make() -> some View {",
                    "        PlaygroundUIKitHost().ignoresSafeArea()", "    }", "}"
                ]
            )
        case .uiKitViewController:
            return (
                [
                    "import SwiftUI", "import UIKit", "",
                    "private struct PlaygroundUIKitHost: UIViewControllerRepresentable {",
                    "    func makeUIViewController(context: Context) -> UIViewController {"
                ],
                [
                    "    }",
                    "    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}",
                    "}", "",
                    "enum PlaygroundEntry {",
                    "    @MainActor static func make() -> some View {",
                    "        PlaygroundUIKitHost().ignoresSafeArea()", "    }", "}"
                ]
            )
        }
    }
}
