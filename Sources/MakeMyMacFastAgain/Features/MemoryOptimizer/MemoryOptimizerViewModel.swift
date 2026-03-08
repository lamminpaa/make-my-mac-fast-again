import Foundation

@MainActor
@Observable
final class MemoryOptimizerViewModel {
    var memoryStats = MemoryStats()
    var isPurging = false
    var statusMessage = ""
    var memoryBefore: UInt64 = 0
    var memoryAfter: UInt64 = 0
    var showResult = false

    private let memoryMonitor = MemoryMonitor()
    private let privilegedExecutor = PrivilegedExecutor()
    private var timer: Timer?

    func startMonitoring() {
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
        memoryStats = memoryMonitor.read()
    }

    func purgeMemory() async {
        isPurging = true
        showResult = false
        statusMessage = "Purging memory (requires admin)..."

        memoryBefore = memoryStats.used

        do {
            _ = try await privilegedExecutor.run("/usr/sbin/purge")

            // Wait for memory stats to settle
            try? await Task.sleep(for: .seconds(2))
            refresh()

            memoryAfter = memoryStats.used
            showResult = true

            let freed = memoryBefore > memoryAfter ? memoryBefore - memoryAfter : 0
            statusMessage = "Memory purge complete. Freed \(ByteFormatter.format(freed))."
        } catch {
            statusMessage = "Memory purge failed: \(error.localizedDescription)"
        }

        isPurging = false
    }
}
