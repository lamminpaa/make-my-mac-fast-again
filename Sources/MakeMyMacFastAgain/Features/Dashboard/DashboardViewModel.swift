import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    var cpuStats = CPUStats()
    var memoryStats = MemoryStats()
    var diskStats = DiskStats()
    var networkStats = NetworkStats()
    var systemName: String = ""
    var macOSVersion: String = ""
    var uptime: String = ""
    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []
    var hasInitialData = false

    private static let maxHistorySamples = 30

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()
    private let processService = ProcessService()
    private var timer: Timer?

    var topProcesses: [AppProcessInfo] = []

    func startMonitoring() {
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
