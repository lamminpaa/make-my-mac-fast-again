import Foundation
import Darwin

@MainActor
@Observable
final class ProcessManagerViewModel {
    var processes: [AppProcessInfo] = []
    var searchText = ""
    var sortOrder: SortOrder = .memory
    var selectedFilter: ProcessFilter = .allProcesses
    var isLoading = false
    var statusMessage = ""
    var selectedProcessID: pid_t?

    private let processService = ProcessService()
    private var timer: Timer?
    private var previousCPUTimes: [pid_t: Double] = [:]
    private let refreshInterval: Double = 3.0
    private let currentUsername = NSUserName()

    enum SortOrder: String, CaseIterable, Sendable {
        case memory = "Memory"
        case cpu = "CPU"
        case name = "Name"
        case pid = "PID"
    }

    enum ProcessFilter: String, CaseIterable, Sendable {
        case allProcesses = "All"
        case myProcesses = "My Processes"
        case applications = "Apps"
        case system = "System"
    }

    var filteredProcesses: [AppProcessInfo] {
        var filtered: [AppProcessInfo]

        // Apply process type filter
        switch selectedFilter {
        case .allProcesses:
            filtered = processes
        case .myProcesses:
            filtered = processes.filter { $0.user == currentUsername }
        case .applications:
            filtered = processes.filter { !$0.name.isEmpty && $0.name.first?.isUppercase == true }
        case .system:
            filtered = processes.filter {
                $0.user == "root" || $0.user == "_windowserver" ||
                $0.user.hasPrefix("_") || $0.user == "daemon"
            }
        }

        // Apply search text filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.user.localizedCaseInsensitiveContains(searchText) ||
                String($0.pid).contains(searchText)
            }
        }

        switch sortOrder {
        case .memory:
            return filtered.sorted { $0.memoryBytes > $1.memoryBytes }
        case .cpu:
            return filtered.sorted { $0.cpuPercentage > $1.cpuPercentage }
        case .name:
            return filtered.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case .pid:
            return filtered.sorted { $0.pid < $1.pid }
        }
    }

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        var currentProcesses = processService.listProcesses()
        var newCPUTimes: [pid_t: Double] = [:]

        for i in currentProcesses.indices {
            let pid = currentProcesses[i].pid
            let currentTime = currentProcesses[i].cpuUsage
            newCPUTimes[pid] = currentTime

            if let previousTime = previousCPUTimes[pid] {
                let delta = currentTime - previousTime
                let percentage = delta / (refreshInterval * 1_000_000_000) * 100
                currentProcesses[i].cpuPercentage = max(0, percentage)
            }
        }

        previousCPUTimes = newCPUTimes
        processes = currentProcesses
        statusMessage = "\(processes.count) processes"
    }

    func killProcess(_ process: AppProcessInfo) async {
        let result = kill(process.pid, SIGTERM)
        if result == 0 {
            statusMessage = "Sent SIGTERM to \(process.name) (PID \(process.pid))"
        } else {
            statusMessage = "Failed to kill \(process.name): \(String(cString: strerror(errno)))"
        }
        try? await Task.sleep(for: .milliseconds(500))
        refresh()
    }

    func forceKillProcess(_ process: AppProcessInfo) async {
        let result = kill(process.pid, SIGKILL)
        if result == 0 {
            statusMessage = "Sent SIGKILL to \(process.name) (PID \(process.pid))"
        } else {
            statusMessage = "Failed to force kill \(process.name): \(String(cString: strerror(errno)))"
        }
        try? await Task.sleep(for: .milliseconds(500))
        refresh()
    }
}
