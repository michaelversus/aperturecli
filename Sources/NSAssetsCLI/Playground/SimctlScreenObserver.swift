import CryptoKit
import Foundation
import ImageIO

/// Observes a simulator from outside with `simctl`: a screenshot digest, and the guest log for dropped HID events.
struct SimctlScreenObserver: SimulatorScreenObserving {
    private static let droppedEventPredicate = [
        "eventMessage CONTAINS \"No active service\"",
        "eventMessage CONTAINS \"dropping event\"",
        "process != \"log\""
    ].joined(separator: " AND ")

    let udid: String
    let commandRunner = SubprocessRunner()

    func screenDigest() async throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("nsassets-playground-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: path) }
        _ = try commandRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "io", udid, "screenshot", "--type=png", path.path]
        )
        let data = try Data(contentsOf: path)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The simulator's screen size in pixels, from the PNG that `simctl` writes.
    func screenSizeInPixels() throws -> (width: Int, height: Int) {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("nsassets-playground-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: path) }
        _ = try commandRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "io", udid, "screenshot", "--type=png", path.path]
        )
        guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw PlaygroundError.commandFailed("could not read the screenshot size") }
        return (width, height)
    }

    func droppedEventLogLines(since start: Date) async throws -> [String] {
        let seconds = max(2, Int(Date().timeIntervalSince(start).rounded(.up)) + 1)
        let output = try commandRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: [
                "simctl", "spawn", udid, "log", "show", "--style", "compact", "--last", "\(seconds)s",
                "--predicate", Self.droppedEventPredicate
            ]
        )
        return output
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains("No active service") && $0.contains("dropping event") }
    }
}
