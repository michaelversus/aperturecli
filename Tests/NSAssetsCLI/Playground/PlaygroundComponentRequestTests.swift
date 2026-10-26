import Foundation
import Testing
@testable import NSAssetsCLI

struct PlaygroundComponentRequestTests {
    @Test
    func decodesTheMessageTheAppSends() throws {
        let json = """
        {"type":"showComponent","id":"req-1","kind":"uiKitViewController",
         "source":"import UIKit\\nfinal class A: UIViewController {}",
         "entry":"A()","snapshotName":"populated","theme":"dark"}
        """

        let request = try JSONDecoder().decode(PlaygroundComponentRequest.self, from: Data(json.utf8))

        #expect(request.id == "req-1")
        #expect(request.kind == .uiKitViewController)
        #expect(request.source == "import UIKit\nfinal class A: UIViewController {}")
        #expect(request.entry == "A()")
        #expect(request.snapshotName == "populated")
        #expect(request.theme == .dark)
    }

    @Test
    func aMissingAssetsFieldDecodesAsNoAssets() throws {
        let json = #"{"id":"1","kind":"swiftUIView","source":"","entry":"X()","snapshotName":"n","theme":"light"}"#

        let request = try JSONDecoder().decode(PlaygroundComponentRequest.self, from: Data(json.utf8))

        #expect(request.assets == nil)
    }

    @Test
    func decodesAssetEntriesAndIgnoresUnknownFields() throws {
        let json = """
        {"id":"1","kind":"swiftUIView","source":"","entry":"X()","snapshotName":"n","theme":"light",
         "assets":[{"catalog":"Assets","kind":"imageset","path":"/r/A.xcassets/logo.imageset","extra":1},
                   {"catalog":"Assets","kind":"colorset","path":"/r/A.xcassets/brand.colorset"}]}
        """

        let request = try JSONDecoder().decode(PlaygroundComponentRequest.self, from: Data(json.utf8))

        #expect(request.assets?.map(\.kind) == [.imageset, .colorset])
        #expect(request.assets?.map(\.name) == ["logo", "brand"])
    }

    @Test(arguments: ["swiftUIView", "uiKitView", "uiKitViewController"])
    func everyKindDecodes(kind: String) throws {
        let json = #"{"id":"1","kind":"\#(kind)","source":"","entry":"X()","snapshotName":"n","theme":"light"}"#

        #expect(throws: Never.self) {
            try JSONDecoder().decode(PlaygroundComponentRequest.self, from: Data(json.utf8))
        }
    }

    @Test
    func anUnknownKindDoesNotDecode() {
        let json = #"{"id":"1","kind":"watchView","source":"","entry":"X()","snapshotName":"n","theme":"light"}"#

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PlaygroundComponentRequest.self, from: Data(json.utf8))
        }
    }

    @Test
    func aStatusEncodesWithItsMessageTypeAndDiagnostics() throws {
        let status = PlaygroundComponentStatus(
            id: "req-1",
            state: .failed,
            message: "Build failed.",
            diagnostics: [
                PlaygroundDiagnostic(file: .component, line: 3, column: 5, severity: .error, message: "oops")
            ]
        )

        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(status)) as? [String: Any]
        )
        let diagnostics = try #require(object["diagnostics"] as? [[String: Any]])

        #expect(object["type"] as? String == "componentStatus")
        #expect(object["id"] as? String == "req-1")
        #expect(object["state"] as? String == "failed")
        #expect(diagnostics.first?["file"] as? String == "component")
        #expect(diagnostics.first?["line"] as? Int == 3)
        #expect(diagnostics.first?["severity"] as? String == "error")
    }
}
