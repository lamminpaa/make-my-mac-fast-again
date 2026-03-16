import Foundation

enum AppVersion {
    static let version = "1.0.0"
    static let build = "dev"
    static let gitHash = "unknown"

    static var fullVersion: String {
        if gitHash != "unknown" {
            return "\(version) (\(build)) [\(gitHash)]"
        }
        return "\(version) (\(build))"
    }

    static var shortVersion: String {
        "\(version) (\(build))"
    }
}
