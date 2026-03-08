import Foundation
import AppKit

final class PrivilegedExecutor {
    enum PrivilegedError: LocalizedError {
        case authorizationFailed
        case scriptError(String)
        case disallowedCommand(String)

        var errorDescription: String? {
            switch self {
            case .authorizationFailed:
                return "Administrator authorization was denied."
            case .scriptError(let message):
                return "Privileged command failed: \(message)"
            case .disallowedCommand(let command):
                return "Command not allowed: \(command)"
            }
        }
    }

    /// Allowed command prefixes for privileged execution.
    /// Commands must start with one of these prefixes to be executed.
    private static let allowedCommandPrefixes: [String] = [
        "killall -HUP mDNSResponder",
        "/usr/sbin/purge",
        "rm -rf '/Library/Caches'",
        "rm -rf '",
        "launchctl"
    ]

    @MainActor
    func run(_ command: String) async throws -> String {
        // Validate command against whitelist
        let isAllowed = Self.allowedCommandPrefixes.contains { prefix in
            command.hasPrefix(prefix)
        }
        guard isAllowed else {
            throw PrivilegedError.disallowedCommand(command)
        }

        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "'", with: "'\\''")

        let appleScript = """
        do shell script "\(escapedCommand)" with administrator privileges
        """

        let script = NSAppleScript(source: appleScript)
        var errorDict: NSDictionary?

        guard let result = script?.executeAndReturnError(&errorDict) else {
            if let error = errorDict {
                let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                if message.contains("User canceled") || message.contains("-128") {
                    throw PrivilegedError.authorizationFailed
                }
                throw PrivilegedError.scriptError(message)
            }
            throw PrivilegedError.authorizationFailed
        }

        return result.stringValue ?? ""
    }
}
