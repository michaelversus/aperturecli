import Testing
@testable import NSAssetsCLI

struct SubprocessEnvironmentSanitizerTests {
    @Test
    func sanitizeRemovesKnownXcodeWarningVariables() {
        let sanitized = SubprocessEnvironmentSanitizer.sanitize(
            [
                "HOME": "/Users/me",
                "SWIFT_DEBUG_INFORMATION_FORMAT": "dwarf",
                "SWIFT_DEBUG_INFORMATION_VERSION": "5.0",
            ]
        )

        #expect(sanitized["HOME"] == "/Users/me")
        #expect(sanitized["SWIFT_DEBUG_INFORMATION_FORMAT"] == nil)
        #expect(sanitized["SWIFT_DEBUG_INFORMATION_VERSION"] == nil)
    }

    @Test
    func sanitizeRemovesRelativeDeveloperDirectoryPath() {
        let sanitized = SubprocessEnvironmentSanitizer.sanitize(
            ["XCODE_DEVELOPER_DIR_PATH": "Contents/Developer"]
        )

        #expect(sanitized["XCODE_DEVELOPER_DIR_PATH"] == nil)
    }

    @Test
    func sanitizeKeepsAbsoluteDeveloperDirectoryPath() {
        let path = "/Applications/Xcode.app/Contents/Developer"
        let sanitized = SubprocessEnvironmentSanitizer.sanitize(
            ["XCODE_DEVELOPER_DIR_PATH": path]
        )

        #expect(sanitized["XCODE_DEVELOPER_DIR_PATH"] == path)
    }
}
