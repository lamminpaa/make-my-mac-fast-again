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

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()
    private var timer: Timer?

    func startMonitoring() {
        loadSystemInfo()
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
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
