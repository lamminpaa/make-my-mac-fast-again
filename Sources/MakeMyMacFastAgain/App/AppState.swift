import Foundation
import SwiftUI

/// Central application state that owns shared monitor instances and drives
/// a single refresh timer. Feature ViewModels read from AppState instead of
/// creating their own monitors, eliminating duplicate work.
@MainActor
@Observable
final class AppState {
    // MARK: - Published Stats

    var cpuStats = CPUStats()
    var memoryStats = MemoryStats()
    var diskStats = DiskStats()
    var networkStats = NetworkStats()

    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []

    var topProcesses: [AppProcessInfo] = []

    var systemName: String = ""
    var macOSVersion: String = ""
    var uptime: String = ""

    var hasInitialData = false

    // MARK: - Shared Services

    let cpuMonitor = CPUMonitor()
    let memoryMonitor = MemoryMonitor()
    let diskMonitor = DiskMonitor()
    let networkMonitor = NetworkMonitor()
    let processService = ProcessService()

    // MARK: - Private

    private static let maxHistorySamples = 30
    private var timer: Timer?

    // MARK: - Lifecycle

    func startMonitoring() {
        guard timer == nil else { return }
        loadSystemInfo()
        refresh()

        let interval = AppSettings.load().dashboardRefreshInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Refresh

    private func refresh() {
        cpuStats = cpuMonitor.read()
        memoryStats = memoryMonitor.read()
        diskStats = diskMonitor.read()
        networkStats = networkMonitor.read()
        uptime = formatUptime()

        cpuHistory.append(cpuStats.totalUsage)
        if cpuHistory.count > Self.maxHistorySamples {
            cpuHistory.removeFirst(cpuHistory.count - Self.maxHistorySamples)
        }

        memoryHistory.append(memoryStats.usagePercentage)
        if memoryHistory.count > Self.maxHistorySamples {
            memoryHistory.removeFirst(memoryHistory.count - Self.maxHistorySamples)
        }

        let allProcesses = processService.listProcesses()
        topProcesses = Array(allProcesses.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(5))

        if !hasInitialData {
            hasInitialData = true
        }
    }

    // MARK: - System Info

    private func loadSystemInfo() {
        let info = Foundation.ProcessInfo.processInfo
        systemName = Host.current().localizedName ?? "Mac"

        let version = info.operatingSystemVersion
        macOSVersion = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func formatUptime() -> String {
        let uptime = Foundation.ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h \(minutes)m"
        }
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - SwiftUI Environment

private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

extension EnvironmentValues {
    var appState: AppState? {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
