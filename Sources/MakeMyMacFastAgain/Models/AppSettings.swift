import Foundation

struct AppSettings: Codable, Sendable {
    var dashboardRefreshInterval: TimeInterval = 2.0
    var processRefreshInterval: TimeInterval = 3.0
    var confirmBeforeCleanup: Bool = true
    var confirmBeforeKillProcess: Bool = true

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
}
