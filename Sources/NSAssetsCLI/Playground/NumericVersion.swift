import Foundation

enum NumericVersion {
    /// Compares dotted versions component by component as integers, so "1155.10" is newer than "1155.4".
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let leftPart = index < left.count ? left[index] : 0
            let rightPart = index < right.count ? right[index] : 0
            if leftPart != rightPart { return leftPart < rightPart ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
