import Foundation

actor ShellExecutor {
    struct CommandResult: Sendable {
        let output: String
        let errorOutput: String
        let exitCode: Int32
        var succeeded: Bool { exitCode == 0 }
    }

    func run(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return CommandResult(
            output: output,
            errorOutput: errorOutput,
            exitCode: process.terminationStatus
        )
    }
}
