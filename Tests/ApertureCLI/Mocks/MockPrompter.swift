import Testing
@testable import ApertureCLI

final class MockPrompter: InitialSetupPrompting {
    private var requiredValues: [String]
    private var confirmations: [Bool]
    private let selectedSchemes: [String]

    private(set) var promptedValues: [String] = []
    private(set) var confirmationPrompts: [String] = []
    private(set) var selectionInputs: [[String]] = []
    private(set) var spinnerPrefixes: [String] = []
    private(set) var messages: [String] = []

    init(
        requiredValues: [String] = [],
        confirmations: [Bool] = [],
        selectedSchemes: [String] = []
    ) {
        self.requiredValues = requiredValues
        self.confirmations = confirmations
        self.selectedSchemes = selectedSchemes
    }

    func writeMessage(_ message: String) {
        messages.append(message)
    }

    func promptRequiredValue(_ prompt: String) throws -> String {
        promptedValues.append(prompt)
        guard !requiredValues.isEmpty else {
            Issue.record("Unexpected prompt: \(prompt)")
            return ""
        }
        return requiredValues.removeFirst()
    }

    func promptConfirmation(_ prompt: String, defaultValue: Bool) throws -> Bool {
        confirmationPrompts.append(prompt)
        guard !confirmations.isEmpty else {
            return defaultValue
        }
        return confirmations.removeFirst()
    }

    func promptSnapshotTestSchemes(from discoveredSchemes: [String]) throws -> [String] {
        selectionInputs.append(discoveredSchemes)
        return selectedSchemes
    }

    func performWithSpinner<T>(
        prefix: String,
        operation: @escaping () throws -> T
    ) async throws -> T {
        spinnerPrefixes.append(prefix)
        return try operation()
    }
}
