import Foundation

enum SubprocessRunnerError: LocalizedError, Equatable {
    case commandFailed(
        executable: String,
        arguments: [String],
        exitCode: Int32,
        output: String
    )
    case invalidOutputEncoding

    var errorDescription: String? {
        switch self {
        case .commandFailed(let executable, let arguments, let exitCode, let output):
            let command = ([executable] + arguments).joined(separator: " ")
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedOutput.isEmpty {
                return "❌ Command failed (\(exitCode)): \(command)\n\(trimmedOutput)"
            }
            return "❌ Command failed (\(exitCode)): \(command)"
        case .invalidOutputEncoding:
            return "❌ Failed to decode command output as UTF-8."
        }
    }
}

struct SubprocessRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let combinedOutputPipe = Pipe()
        process.standardOutput = combinedOutputPipe
        process.standardError = combinedOutputPipe

        try process.run()
        let outputData = combinedOutputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw SubprocessRunnerError.invalidOutputEncoding
        }

        guard process.terminationStatus == 0 else {
            throw SubprocessRunnerError.commandFailed(
                executable: executable,
                arguments: arguments,
                exitCode: process.terminationStatus,
                output: output
            )
        }

        return output
    }
}
