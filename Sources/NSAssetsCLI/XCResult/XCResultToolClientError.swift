import Foundation

enum XCResultToolClientError: LocalizedError, Equatable {
    case invalidJSON(command: String, underlying: String)
    case missingManifest(path: String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let command, let underlying):
            "❌ Failed to decode JSON output for command '\(command)': \(underlying)"
        case .missingManifest(let path):
            "❌ Missing attachments manifest at \(path)."
        }
    }
}
