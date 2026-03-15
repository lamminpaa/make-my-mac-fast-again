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

    private weak var appState: AppState?
    private var timer: Timer?
    private var previousCPUTimes: [pid_t: Double] = [:]
    private var lastRefreshTimestamp: Date?
    private var refreshInterval: Double = 3.0
    private let currentUsername = NSUserName()
    private let ownPID = getpid()

    /// PIDs that must never be killed (kernel idle process, launchd)
    private static let protectedPIDs: Set<pid_t> = [0, 1]

    /// Process names that must never be killed
    private static let protectedNames: Set<String> = ["kernel_task"]

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

    func bind(to appState: AppState) {
        self.appState = appState
    }

    func startMonitoring() {
        timer?.invalidate()
        refreshInterval = AppSettings.load().processRefreshInterval
        lastRefreshTimestamp = Date()
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
        guard let processService = appState?.processService else { return }
        let now = Date()
        let elapsed = lastRefreshTimestamp.map { now.timeIntervalSince($0) } ?? refreshInterval
        lastRefreshTimestamp = now

        var currentProcesses = processService.listProcesses()
        var newCPUTimes: [pid_t: Double] = [:]

        for i in currentProcesses.indices {
            let pid = currentProcesses[i].pid
            let currentTime = currentProcesses[i].cpuUsage
            newCPUTimes[pid] = currentTime

            if let previousTime = previousCPUTimes[pid], elapsed > 0 {
                let delta = currentTime - previousTime
                let percentage = delta / (elapsed * 1_000_000_000) * 100
                currentProcesses[i].cpuPercentage = max(0, percentage)
            }

            if isProcessProtected(pid: pid, name: currentProcesses[i].name) {
                currentProcesses[i].isProtected = true
            }
        }

        previousCPUTimes = newCPUTimes
        processes = currentProcesses
        statusMessage = "\(processes.count) processes"
    }

    private func isProcessProtected(pid: pid_t, name: String) -> Bool {
        pid == ownPID
            || Self.protectedPIDs.contains(pid)
            || Self.protectedNames.contains(name)
    }

    func killProcess(_ process: AppProcessInfo) async {
        if let reason = safetyCheckFailure(for: process) {
            statusMessage = reason
            return
        }

        if let reason = verifyProcessIdentity(process) {
            statusMessage = reason
            return
        }

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
        if let reason = safetyCheckFailure(for: process) {
            statusMessage = reason
            return
        }

        if let reason = verifyProcessIdentity(process) {
            statusMessage = reason
            return
        }

        let result = kill(process.pid, SIGKILL)
        if result == 0 {
            statusMessage = "Sent SIGKILL to \(process.name) (PID \(process.pid))"
        } else {
            statusMessage = "Failed to force kill \(process.name): \(String(cString: strerror(errno)))"
        }
        try? await Task.sleep(for: .milliseconds(500))
        refresh()
    }

    /// Returns a user-facing reason string if the process must not be killed, nil otherwise.
    private func safetyCheckFailure(for process: AppProcessInfo) -> String? {
        if process.pid == ownPID {
            return "Cannot kill own application"
        }
        if Self.protectedPIDs.contains(process.pid) {
            return "Cannot kill system process \(process.name) (PID \(process.pid))"
        }
        if Self.protectedNames.contains(process.name) {
            return "Cannot kill protected process \(process.name)"
        }
        return nil
    }

    /// Re-reads the process to guard against PID reuse race conditions.
    /// Returns a reason string if the process identity no longer matches, nil if safe to proceed.
    private func verifyProcessIdentity(_ process: AppProcessInfo) -> String? {
        guard let processService = appState?.processService else {
            return "Process service unavailable"
        }
        guard let current = processService.getProcessInfo(pid: process.pid) else {
            return "Process \(process.name) (PID \(process.pid)) no longer exists"
        }
        if current.name != process.name {
            return "PID \(process.pid) is now \"\(current.name)\" (was \"\(process.name)\") — aborting kill to avoid targeting the wrong process"
        }
        return nil
    }
}
