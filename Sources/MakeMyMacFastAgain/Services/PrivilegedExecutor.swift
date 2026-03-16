import Foundation
import AppKit
import os

enum LaunchctlAction: String, Sendable {
    case enable
    case disable
}

enum PrivilegedCommand: Sendable {
    case flushDNS
    case purgeMemory
    case removeCache(path: String)
    case launchctl(action: LaunchctlAction, domain: String, label: String)
}

final class PrivilegedExecutor {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "privileged")

    enum PrivilegedError: LocalizedError {
        case authorizationFailed
        case scriptError(String)
        case invalidCachePath(String)
        case invalidLaunchctlDomain(String)
        case invalidLaunchctlLabel(String)

        var errorDescription: String? {
            switch self {
            case .authorizationFailed:
                return "Administrator authorization was denied."
            case .scriptError(let message):
                return "Privileged command failed: \(message)"
            case .invalidCachePath(let path):
                return "Cache path not allowed: \(path)"
            case .invalidLaunchctlDomain(let domain):
                return "Launchctl domain not allowed: \(domain)"
            case .invalidLaunchctlLabel(let label):
                return "Launchctl label not allowed: \(label)"
            }
        }
    }

    /// Allowed cache path prefixes. Paths must start with one of these.
    private static let allowedCachePrefixes: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/Library/Caches",
            "\(home)/Library/Caches",
        ]
    }()

    /// Pattern for valid launchctl labels: alphanumerics, dots, hyphens, underscores.
    private static let labelAllowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))

    private static func isValidLaunchctlDomain(_ domain: String) -> Bool {
        if domain == "system" { return true }
        if domain.hasPrefix("gui/") {
            let uidPart = domain.dropFirst(4)
            return !uidPart.isEmpty && uidPart.allSatisfy(\.isNumber)
        }
        return false
    }

    func buildShellCommand(_ command: PrivilegedCommand) throws -> String {
        switch command {
        case .flushDNS:
            return "killall -HUP mDNSResponder"

        case .purgeMemory:
            return "/usr/sbin/purge"

        case .removeCache(let path):
            let resolved = resolveTilde(path)

            let isAllowed = Self.allowedCachePrefixes.contains { prefix in
                resolved.hasPrefix(prefix)
            }
            guard isAllowed else {
                throw PrivilegedError.invalidCachePath(path)
            }

            // Reject path traversal
            guard !resolved.contains("..") else {
                throw PrivilegedError.invalidCachePath(path)
            }

            let escaped = shellEscapeSingleQuote(resolved)
            return "rm -rf '\(escaped)'/*"

        case .launchctl(let action, let domain, let label):
            guard Self.isValidLaunchctlDomain(domain) else {
                throw PrivilegedError.invalidLaunchctlDomain(domain)
            }

            guard !label.isEmpty,
                  label.unicodeScalars.allSatisfy({ Self.labelAllowedCharacters.contains($0) }) else {
                throw PrivilegedError.invalidLaunchctlLabel(label)
            }

            return "launchctl \(action.rawValue) \(domain)/\(label)"
        }
    }

    private func resolveTilde(_ path: String) -> String {
        if path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return home + path.dropFirst(1)
        }
        return path
    }

    private func shellEscapeSingleQuote(_ string: String) -> String {
        string.replacingOccurrences(of: "'", with: "'\\''")
    }

    @MainActor
    func run(_ command: PrivilegedCommand) async throws -> String {
        logger.info("Executing privileged command: \(String(describing: command))")
        let shellCommand = try buildShellCommand(command)

        // Escape characters special to AppleScript's do shell script (double-quoted context)
        let escapedCommand = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")

        let appleScript = """
        do shell script "\(escapedCommand)" with administrator privileges
        """

        let script = NSAppleScript(source: appleScript)
        var errorDict: NSDictionary?

        guard let result = script?.executeAndReturnError(&errorDict) else {
            if let error = errorDict {
                let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                if message.contains("User canceled") || message.contains("-128") {
                    logger.error("Privileged command denied by user")
                    throw PrivilegedError.authorizationFailed
                }
                logger.error("Privileged command failed: \(message)")
                throw PrivilegedError.scriptError(message)
            }
            logger.error("Privileged command failed: authorization error")
            throw PrivilegedError.authorizationFailed
        }

        return result.stringValue ?? ""
    }
}
