import Foundation
import AppKit

final class PrivilegedExecutor {
    enum PrivilegedError: LocalizedError {
        case authorizationFailed
        case scriptError(String)

        var errorDescription: String? {
            switch self {
            case .authorizationFailed:
                return "Administrator authorization was denied."
            case .scriptError(let message):
                return "Privileged command failed: \(message)"
            }
        }
    }

    @MainActor
    func run(_ command: String) async throws -> String {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

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
