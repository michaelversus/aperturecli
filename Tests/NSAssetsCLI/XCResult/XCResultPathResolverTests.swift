import Foundation
import Testing
@testable import NSAssetsCLI

struct XCResultPathResolverTests {
    @Test
    func resolvesNewestMatchingXCResultPath() throws {
        let (derivedDataURL, cleanup) = try makeTemporaryDirectory()
        defer { cleanup() }

        let testLogsURL = derivedDataURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Test", isDirectory: true)
        try FileManager.default.createDirectory(at: testLogsURL, withIntermediateDirectories: true)

        let oldDate = Date(timeIntervalSince1970: 1_000)
        let newDate = Date(timeIntervalSince1970: 2_000)
        let ignoredNewerDate = Date(timeIntervalSince1970: 3_000)

        let oldMatch = testLogsURL.appendingPathComponent("Run-Snapshots-old.xcresult", isDirectory: true)
        let newMatch = testLogsURL.appendingPathComponent("Run.snapshots.new.xcresult", isDirectory: true)
        let nonMatch = testLogsURL.appendingPathComponent("Run-Other-newest.xcresult", isDirectory: true)

        try createXCResultBundle(at: oldMatch, modificationDate: oldDate)
        try createXCResultBundle(at: newMatch, modificationDate: newDate)
        try createXCResultBundle(at: nonMatch, modificationDate: ignoredNewerDate)

        let locator = MockDerivedDataLocator(
            result: .success(
                DerivedDataPaths(
                    derivedDataURL: derivedDataURL,
                    shouldAppendExtraPaths: false
                )
            )
        )
        let resolver = XCResultPathResolver(
            fileSystem: FileSystem(fileManager: .default),
            derivedDataLocator: locator
        )

        let path = try resolver.resolvePath(schemeName: "Snapshots", projectName: "MyApp")

        #expect(locator.locateCallCount == 1)
        #expect(locator.receivedProjectName == "MyApp")
        #expect(
            URL(fileURLWithPath: path).resolvingSymlinksInPath().path
                == newMatch.resolvingSymlinksInPath().path
        )
    }

    @Test
    func throwsWhenTestLogsDirectoryIsMissing() throws {
        let (derivedDataURL, cleanup) = try makeTemporaryDirectory()
        defer { cleanup() }

        let locator = MockDerivedDataLocator(
            result: .success(
                DerivedDataPaths(
                    derivedDataURL: derivedDataURL,
                    shouldAppendExtraPaths: false
                )
            )
        )
        let resolver = XCResultPathResolver(
            fileSystem: FileSystem(fileManager: .default),
            derivedDataLocator: locator
        )

        let expectedPath = derivedDataURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Test", isDirectory: true)
            .path
        #expect(
            throws: XCResultPathResolverError.missingTestLogsDirectory(path: expectedPath)
        ) {
            try resolver.resolvePath(schemeName: "Snapshots", projectName: "MyApp")
        }
    }

    @Test
    func throwsWhenNoXCResultFilesExist() throws {
        let (derivedDataURL, cleanup) = try makeTemporaryDirectory()
        defer { cleanup() }

        let testLogsURL = derivedDataURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Test", isDirectory: true)
        try FileManager.default.createDirectory(at: testLogsURL, withIntermediateDirectories: true)

        let locator = MockDerivedDataLocator(
            result: .success(
                DerivedDataPaths(
                    derivedDataURL: derivedDataURL,
                    shouldAppendExtraPaths: false
                )
            )
        )
        let resolver = XCResultPathResolver(
            fileSystem: FileSystem(fileManager: .default),
            derivedDataLocator: locator
        )

        #expect(
            throws: XCResultPathResolverError.noXCResultFiles(path: testLogsURL.path)
        ) {
            try resolver.resolvePath(schemeName: "Snapshots", projectName: "MyApp")
        }
    }

    @Test
    func throwsWhenSchemeMatchIsMissing() throws {
        let (derivedDataURL, cleanup) = try makeTemporaryDirectory()
        defer { cleanup() }

        let testLogsURL = derivedDataURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Test", isDirectory: true)
        try FileManager.default.createDirectory(at: testLogsURL, withIntermediateDirectories: true)

        let xcresult = testLogsURL.appendingPathComponent("Run-Other.xcresult", isDirectory: true)
        try createXCResultBundle(
            at: xcresult,
            modificationDate: Date(timeIntervalSince1970: 1_000)
        )

        let locator = MockDerivedDataLocator(
            result: .success(
                DerivedDataPaths(
                    derivedDataURL: derivedDataURL,
                    shouldAppendExtraPaths: false
                )
            )
        )
        let resolver = XCResultPathResolver(
            fileSystem: FileSystem(fileManager: .default),
            derivedDataLocator: locator
        )

        #expect(
            throws: XCResultPathResolverError.noSchemeMatch(
                schemeName: "Snapshots",
                searchPath: testLogsURL.path
            )
        ) {
            try resolver.resolvePath(schemeName: "Snapshots", projectName: "MyApp")
        }
    }

    @Test
    func throwsWhenArgumentsAreEmpty() throws {
        let locator = MockDerivedDataLocator(
            result: .success(
                DerivedDataPaths(
                    derivedDataURL: URL(fileURLWithPath: "/tmp", isDirectory: true),
                    shouldAppendExtraPaths: false
                )
            )
        )
        let resolver = XCResultPathResolver(
            fileSystem: FileSystem(fileManager: .default),
            derivedDataLocator: locator
        )

        #expect(throws: XCResultPathResolverError.invalidArguments) {
            try resolver.resolvePath(schemeName: "   ", projectName: "MyApp")
        }
        #expect(throws: XCResultPathResolverError.invalidArguments) {
            try resolver.resolvePath(schemeName: "Snapshots", projectName: " ")
        }
        #expect(locator.locateCallCount == 0)
    }

    private func makeTemporaryDirectory() throws -> (URL, () -> Void) {
        let baseURL = FileManager.default.temporaryDirectory
        let url = baseURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return (url, { try? FileManager.default.removeItem(at: url) })
    }

    private func createXCResultBundle(at url: URL, modificationDate: Date) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.modificationDate: modificationDate],
            ofItemAtPath: url.path
        )
    }
}
