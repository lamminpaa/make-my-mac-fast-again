import Foundation
import SwiftUI

/// Thin wrapper that reads all monitoring data from the shared AppState.
/// Kept as a separate type so DashboardView can remain a struct with @State.
@MainActor
@Observable
final class DashboardViewModel {
    private weak var appState: AppState?

    var cpuStats: CPUStats { appState?.cpuStats ?? CPUStats() }
    var loadStats: LoadStats { appState?.loadStats ?? LoadStats() }
    var memoryStats: MemoryStats { appState?.memoryStats ?? MemoryStats() }
    var diskStats: DiskStats { appState?.diskStats ?? DiskStats() }
    var networkStats: NetworkStats { appState?.networkStats ?? NetworkStats() }
    var systemName: String { appState?.systemName ?? "" }
    var macOSVersion: String { appState?.macOSVersion ?? "" }
    var uptime: String { appState?.uptime ?? "" }
    var cpuHistory: [Double] { appState?.cpuHistory ?? [] }
    var memoryHistory: [Double] { appState?.memoryHistory ?? [] }
    var hasInitialData: Bool { appState?.hasInitialData ?? false }
    var topProcesses: [AppProcessInfo] { appState?.topProcesses ?? [] }
    var zombiePollers: [ZombiePoller] { appState?.zombiePollers ?? [] }

    /// Cached settings — loaded once on bind, refreshed after cleanup.
    var lastCleanupDate: Date?
    var lastCleanupFreedBytes: UInt64?

    func bind(to appState: AppState) {
        self.appState = appState
        reloadSettings()
    }

    func reloadSettings() {
        let settings = AppSettings.load()
        lastCleanupDate = settings.lastCleanupDate
        lastCleanupFreedBytes = settings.lastCleanupFreedBytes
    }
}
