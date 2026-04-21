import Foundation
import Darwin
import os

@MainActor
@Observable
final class ProcessManagerViewModel {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "process-manager")
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

    /// Lookup table rebuilt on every refresh. Used to resolve parent chains
    /// without walking the flat `processes` array repeatedly.
    private(set) var processesByPID: [pid_t: AppProcessInfo] = [:]

    /// Maximum ancestor-chain depth before we abort the walk. Real shells sit
    /// around 5–10 deep; the cap is purely defensive against pathological data.
    private static let maxChainDepth = 64

    /// PIDs that must never be killed (kernel idle process, launchd)
    private static let protectedPIDs: Set<pid_t> = [0, 1]

    /// Process names that must never be killed
    private static let protectedNames: Set<String> = ["kernel_task"]

    enum SortOrder: String, CaseIterable, Sendable {
        case memory = "Memory"
        case cpu = "CPU"
        case name = "Name"
        case pid = "PID"
        case parentTree = "Parent tree"
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
        case .parentTree:
            return sortedByParentTree(filtered)
        }
    }

    /// Walks ppid upward from `pid`, returning ancestors ordered nearest-first
    /// (immediate parent, grandparent, …). Stops at PID 0/1 (kernel / launchd)
    /// and at any unresolvable PPID. Cycle-safe via a visited set.
    func ancestors(of pid: pid_t, includingSelf: Bool = false) -> [AppProcessInfo] {
        var chain: [AppProcessInfo] = []
        var visited: Set<pid_t> = [pid]
        var cursor = pid

        if includingSelf, let selfProc = processesByPID[pid] {
            chain.append(selfProc)
        }

        for _ in 0..<Self.maxChainDepth {
            guard let current = processesByPID[cursor] else { break }
            let nextPID = current.ppid
            if nextPID <= 1 { break }
            if visited.contains(nextPID) { break }
            visited.insert(nextPID)
            guard let parent = processesByPID[nextPID] else { break }
            chain.append(parent)
            cursor = nextPID
        }
        return chain
    }

    /// Depth-first sort key: the full PID chain from root down to self.
    /// Comparing these lexicographically groups children immediately under
    /// their parent and keeps sibling ordering stable.
    private func parentChainSortKey(for process: AppProcessInfo) -> [pid_t] {
        var key = ancestors(of: process.pid).reversed().map(\.pid)
        key.append(process.pid)
        return key
    }

    private func sortedByParentTree(_ processes: [AppProcessInfo]) -> [AppProcessInfo] {
        let keyed = processes.map { ($0, parentChainSortKey(for: $0)) }
        let sorted = keyed.sorted { lhs, rhs in
            let a = lhs.1
            let b = rhs.1
            let common = min(a.count, b.count)
            for i in 0..<common where a[i] != b[i] {
                return a[i] < b[i]
            }
            return a.count < b.count
        }
        return sorted.map(\.0)
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
        processesByPID = Dictionary(uniqueKeysWithValues: currentProcesses.map { ($0.pid, $0) })
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
            logger.info("Sent SIGTERM to \(process.name, privacy: .public) (PID \(process.pid, privacy: .public))")
            statusMessage = "Sent SIGTERM to \(process.name) (PID \(process.pid))"
        } else {
            logger.warning("Failed to kill \(process.name, privacy: .public) (PID \(process.pid, privacy: .public)): \(String(cString: strerror(errno)))")
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
            logger.info("Sent SIGKILL to \(process.name, privacy: .public) (PID \(process.pid, privacy: .public))")
            statusMessage = "Sent SIGKILL to \(process.name) (PID \(process.pid))"
        } else {
            logger.warning("Failed to force kill \(process.name, privacy: .public) (PID \(process.pid, privacy: .public)): \(String(cString: strerror(errno)))")
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

    #if DEBUG
    /// Seed `processes` + `processesByPID` without a live system. Test-only.
    func _seedProcesses(_ seed: [AppProcessInfo]) {
        processes = seed
        processesByPID = Dictionary(uniqueKeysWithValues: seed.map { ($0.pid, $0) })
    }
    #endif

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
