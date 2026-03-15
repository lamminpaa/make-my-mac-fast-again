import Foundation

struct AppSettings: Codable, Sendable {
    var dashboardRefreshInterval: TimeInterval = 2.0
    var processRefreshInterval: TimeInterval = 3.0
    var confirmBeforeCleanup: Bool = true
    var confirmBeforeKillProcess: Bool = true
    var lastCleanupDate: Date?
    var lastCleanupFreedBytes: UInt64?

    private static let key = "AppSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return AppSettings()
        }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    mutating func recordCleanup(freedBytes: UInt64) {
        lastCleanupDate = Date()
        lastCleanupFreedBytes = freedBytes
        save()
    }

    /// Remove stored settings from UserDefaults.
    static func clearStorage() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Write arbitrary string data to the settings key (for testing corrupted data recovery).
    static func writeCorruptedStorage(_ string: String) {
        if let data = string.data(using: .utf8) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
