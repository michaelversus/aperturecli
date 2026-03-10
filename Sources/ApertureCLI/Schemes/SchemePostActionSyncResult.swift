import Foundation

struct SchemePostActionSyncResult: Sendable {
    let matchedSchemeNames: [String]
    let updatedSchemeFilePaths: [String]
    let missingSelectedSchemeNames: [String]

    var matchedSchemeCount: Int {
        matchedSchemeNames.count
    }

    var updatedSchemeFileCount: Int {
        updatedSchemeFilePaths.count
    }
}

enum SchemePostActionSyncReporting {
    static func lines(for result: SchemePostActionSyncResult) -> [String] {
        var lines = [
            "Matched schemes: \(result.matchedSchemeCount)",
            "Updated scheme files: \(result.updatedSchemeFileCount)",
            "Missing selected schemes: \(result.missingSelectedSchemeNames.count)"
        ]

        if !result.missingSelectedSchemeNames.isEmpty {
            lines.append(
                "Skipped missing schemes: \(result.missingSelectedSchemeNames.joined(separator: ", "))"
            )
        }

        return lines
    }
}
