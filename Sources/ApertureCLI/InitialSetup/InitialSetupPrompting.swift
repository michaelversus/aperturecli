import Foundation

protocol InitialSetupPrompting {
    func writeMessage(_ message: String)
    func promptRequiredValue(_ prompt: String) throws -> String
    func promptConfirmation(_ prompt: String, defaultValue: Bool) throws -> Bool
    func promptSnapshotTestSchemes(from discoveredSchemes: [String]) throws -> [String]
    func performWithSpinner<T>(
        prefix: String,
        operation: @escaping () throws -> T
    ) async throws -> T
}
