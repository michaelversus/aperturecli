import Foundation

enum XCResultPathResolverError: LocalizedError, Equatable {
    case invalidArguments
    case missingTestLogsDirectory(path: String)
    case noXCResultFiles(path: String)
    case noSchemeMatch(schemeName: String, searchPath: String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "❌ Both schemeName and projectName must be non-empty."
        case .missingTestLogsDirectory(let path):
            "❌ Test logs directory was not found at \(path)."
        case .noXCResultFiles(let path):
            "❌ No .xcresult files were found at \(path)."
        case .noSchemeMatch(let schemeName, let searchPath):
            "❌ No .xcresult file matching scheme '\(schemeName)' was found in \(searchPath)."
        }
    }
}
