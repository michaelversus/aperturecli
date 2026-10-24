import Foundation
import Testing
@testable import NSAssetsCLI

struct NumericVersionTests {
    @Test(arguments: [
        ("1155.10", "1155.4", ComparisonResult.orderedDescending),
        ("1155.3", "1155.4", ComparisonResult.orderedAscending),
        ("1155.4", "1155.4", ComparisonResult.orderedSame),
        ("1155.4.0", "1155.4", ComparisonResult.orderedSame),
        ("1174.9.2", "1155.4", ComparisonResult.orderedDescending),
        ("9", "10", ComparisonResult.orderedAscending)
    ])
    func comparesComponentsAsIntegers(left: String, right: String, expected: ComparisonResult) {
        #expect(NumericVersion.compare(left, right) == expected)
    }
}
