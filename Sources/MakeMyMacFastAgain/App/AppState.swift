import Foundation
import SwiftUI
import os

/// Central application state that owns shared monitor instances and drives
/// a single refresh timer. Feature ViewModels read from AppState instead of
/// creating their own monitors, eliminating duplicate work.
@MainActor
@Observable
final class AppState {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "app")
    // MARK: - Published Stats

    var cpuStats = CPUStats()
    var memoryStats = MemoryStats()
    var diskStats = DiskStats()
    var networkStats = NetworkStats()

    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []

    var topProcesses: [AppProcessInfo] = []
    var zombieProcessCount: Int = 0

    var systemName: String = ""
    var macOSVersion: String = ""
    var uptime: String = ""

    var hasInitialData = false

    // MARK: - Health Score

    var healthScore: Int {
        let diskScore = usageToScore(diskStats.usagePercentage)
        let memoryScore = usageToScore(memoryStats.usagePercentage)
        let startupScore = 80.0  // placeholder — startup items not in AppState
        let cacheScore = 70.0    // placeholder — cache size not in AppState
        let zombieScore = max(0.0, 100.0 - Double(zombieProcessCount) * 20.0)

        let weighted = diskScore * 0.30
            + memoryScore * 0.25
            + startupScore * 0.20
            + cacheScore * 0.15
            + zombieScore * 0.10

        return Int(weighted.rounded())
    }

    var healthScoreLabel: String {
        switch healthScore {
        case 80...100: return "Excellent"
        case 60...79:  return "Good"
        case 40...59:  return "Fair"
        default:       return "Poor"
        }
    }

    /// Converts a usage percentage (0-100) to a health sub-score.
    /// 100 if usage <60%, linearly decreasing to 0 at 100% usage.
    private func usageToScore(_ usage: Double) -> Double {
        if usage < 60 { return 100 }
        return max(0, (100 - usage) / 40.0 * 100.0)
    }

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
        logger.info("Starting system monitoring")
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
        logger.info("Stopping system monitoring")
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
        zombieProcessCount = allProcesses.filter { $0.status == "Zombie" }.count

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
