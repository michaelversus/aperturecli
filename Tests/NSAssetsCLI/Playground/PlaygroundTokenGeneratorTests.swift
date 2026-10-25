import Testing
@testable import NSAssetsCLI

struct PlaygroundTokenGeneratorTests {
    @Test
    func aTokenIs64LowercaseHexCharacters() throws {
        let token = try PlaygroundTokenGenerator.make()

        #expect(token.count == 64)
        #expect(token.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test
    func everyTokenIsDifferent() throws {
        #expect(try PlaygroundTokenGenerator.make() != PlaygroundTokenGenerator.make())
    }
}
