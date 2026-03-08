import Foundation

@MainActor
@Observable
final class ProcessManagerViewModel {
    var processes: [AppProcessInfo] = []
    var searchText = ""
    var sortOrder: SortOrder = .memory
    var isLoading = false
    var statusMessage = ""
    var selectedProcessID: pid_t?

    private let processService = ProcessService()
    private let shell = ShellExecutor()
    private var timer: Timer?
    private var previousCPUTimes: [pid_t: Double] = [:]
    private let refreshInterval: Double = 3.0
    private let numCPUs = Foundation.ProcessInfo.processInfo.processorCount

    enum SortOrder: String, CaseIterable {
        case memory = "Memory"
        case cpu = "CPU"
        case name = "Name"
        case pid = "PID"
    }

    var filteredProcesses: [AppProcessInfo] {
        let filtered: [AppProcessInfo]
        if searchText.isEmpty {
            filtered = processes
        } else {
            filtered = processes.filter {
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
                let percentage = delta / (refreshInterval * 1_000_000_000 * Double(numCPUs)) * 100
                currentProcesses[i].cpuPercentage = max(0, percentage)
            }
        }

        previousCPUTimes = newCPUTimes
        processes = currentProcesses
        statusMessage = "\(processes.count) processes"
    }

    func killProcess(_ process: AppProcessInfo) async {
        do {
            _ = try await shell.run("kill \(process.pid)")
            statusMessage = "Sent SIGTERM to \(process.name) (PID \(process.pid))"

            // Wait briefly then refresh
            try? await Task.sleep(for: .milliseconds(500))
            refresh()
        } catch {
            statusMessage = "Failed to kill \(process.name): \(error.localizedDescription)"
        }
    }

    func forceKillProcess(_ process: AppProcessInfo) async {
        do {
            _ = try await shell.run("kill -9 \(process.pid)")
            statusMessage = "Sent SIGKILL to \(process.name) (PID \(process.pid))"

            try? await Task.sleep(for: .milliseconds(500))
            refresh()
        } catch {
            statusMessage = "Failed to force kill \(process.name): \(error.localizedDescription)"
        }
    }
}
