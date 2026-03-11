import Foundation

protocol XCResultPathResolving {
    func resolvePath(schemeName: String, projectName: String) throws -> String
}
