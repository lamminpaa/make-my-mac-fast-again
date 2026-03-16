import Foundation
import os

/// Errors that can occur during shell command execution.
enum ShellError: Error, Sendable {
    /// The process did not complete within the allowed time.
    case timeout(seconds: TimeInterval, partialOutput: String)
    /// The executable could not be found at the given path.
    case executableNotFound(String)
}

actor ShellExecutor {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "shell")

    struct CommandResult: Sendable {
        let output: String
        let errorOutput: String
        let exitCode: Int32
        var succeeded: Bool { exitCode == 0 }
    }

    /// Default timeout for shell commands (seconds).
    static let defaultTimeout: TimeInterval = 10

    /// Run a shell command string via `/bin/zsh -c`.
    ///
    /// Use this overload when the command requires shell interpretation
    /// (pipes, redirections, globbing, etc.).
    func run(
        _ command: String,
        timeout: TimeInterval = ShellExecutor.defaultTimeout
    ) async throws -> CommandResult {
        logger.debug("Running shell command: \(command, privacy: .private)")
        do {
            let result = try await executeProcess(
                executablePath: "/bin/zsh",
                arguments: ["-c", command],
                timeout: timeout
            )
            if !result.succeeded {
                logger.error("Shell command exited with code \(result.exitCode): \(result.errorOutput, privacy: .private)")
            }
            return result
        } catch {
            logger.error("Shell command failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Run an executable directly with an arguments array.
    ///
    /// Prefer this overload when no shell interpretation is needed,
    /// as it avoids shell injection risks.
    func run(
        executablePath: String,
        arguments: [String] = [],
        timeout: TimeInterval = ShellExecutor.defaultTimeout
    ) async throws -> CommandResult {
        guard FileManager.default.fileExists(atPath: executablePath) else {
            logger.error("Executable not found: \(executablePath)")
            throw ShellError.executableNotFound(executablePath)
        }
        logger.debug("Running executable: \(executablePath)")
        return try await executeProcess(
            executablePath: executablePath,
            arguments: arguments,
            timeout: timeout
        )
    }

    // MARK: - Private

    private func executeProcess(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        return try await ShellExecutor.awaitProcess(
            process,
            outputPipe: outputPipe,
            errorPipe: errorPipe,
            timeout: timeout
        )
    }

    /// Waits for the process to exit or kills it after `timeout` seconds.
    ///
    /// `nonisolated static` so the blocking work never runs on the actor's
    /// serial executor. Pipe reads and process wait all happen on GCD threads,
    /// with a semaphore providing the timeout gate.
    private nonisolated static func awaitProcess(
        _ process: Process,
        outputPipe: Pipe,
        errorPipe: Pipe,
        timeout: TimeInterval
    ) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let exitSemaphore = DispatchSemaphore(value: 0)

            // Collect pipe data on background threads. readDataToEndOfFile()
            // blocks until the process closes its file descriptors (at exit
            // or after termination), so these must not run inline.
            var outputData = Data()
            var errorData = Data()
            let dataLock = NSLock()

            let outputWorkItem = DispatchWorkItem {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                dataLock.lock()
                outputData = data
                dataLock.unlock()
            }
            let errorWorkItem = DispatchWorkItem {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                dataLock.lock()
                errorData = data
                dataLock.unlock()
            }

            DispatchQueue.global(qos: .userInitiated).async(execute: outputWorkItem)
            DispatchQueue.global(qos: .userInitiated).async(execute: errorWorkItem)

            // Wait for process exit on yet another thread.
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                exitSemaphore.signal()
            }

            let waitResult = exitSemaphore.wait(timeout: .now() + timeout)

            switch waitResult {
            case .success:
                // Process exited within the timeout. The pipe reads will
                // also complete since the process closed its descriptors.
                outputWorkItem.wait()
                errorWorkItem.wait()

                dataLock.lock()
                let outSnapshot = outputData
                let errSnapshot = errorData
                dataLock.unlock()

                let output = String(data: outSnapshot, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let errorOutput = String(data: errSnapshot, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                continuation.resume(returning: CommandResult(
                    output: output,
                    errorOutput: errorOutput,
                    exitCode: process.terminationStatus
                ))

            case .timedOut:
                // SIGTERM first for graceful shutdown.
                process.terminate()

                // Brief grace period, then force-kill if still alive.
                let grace = exitSemaphore.wait(timeout: .now() + 2)
                if grace == .timedOut, process.isRunning {
                    process.interrupt()
                }

                // After termination the pipes will close, so reads finish.
                outputWorkItem.wait()
                errorWorkItem.wait()

                dataLock.lock()
                let outSnapshot = outputData
                dataLock.unlock()

                let partialOutput = String(data: outSnapshot, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                continuation.resume(throwing: ShellError.timeout(
                    seconds: timeout,
                    partialOutput: partialOutput
                ))
            }
        }
    }
}
