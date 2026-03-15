import Foundation
import SwiftUI

struct PurgeHistoryEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let freed: UInt64
}

@MainActor
@Observable
final class MemoryOptimizerViewModel {
    var memoryStats = MemoryStats()
    var isPurging = false
    var statusMessage = ""
    var memoryBefore: UInt64 = 0
    var memoryAfter: UInt64 = 0
    var showResult = false
    var lastPurgeFreed: UInt64?
    var purgeHistory: [PurgeHistoryEntry] = []

    var memoryPressureLevel: MemoryPressureLevel {
        let pct = memoryStats.usagePercentage
        if pct < 60 { return .normal }
        else if pct < 80 { return .warning }
        else { return .critical }
    }

    enum MemoryPressureLevel: Sendable {
        case normal
        case warning
        case critical

        var label: String {
            switch self {
            case .normal: return "Normal"
            case .warning: return "Warning"
            case .critical: return "Critical"
            }
        }

        var color: Color {
            switch self {
            case .normal: return .green
            case .warning: return .yellow
            case .critical: return .red
            }
        }
    }

    private static let maxPurgeHistory = 10

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
            _ = try await privilegedExecutor.run(.purgeMemory)

            // Wait for memory stats to settle
            try? await Task.sleep(for: .seconds(2))
            refresh()

            memoryAfter = memoryStats.used
            showResult = true

            let freed = memoryBefore > memoryAfter ? memoryBefore - memoryAfter : 0
            lastPurgeFreed = freed

            let entry = PurgeHistoryEntry(date: Date(), freed: freed)
            purgeHistory.insert(entry, at: 0)
            if purgeHistory.count > Self.maxPurgeHistory {
                purgeHistory = Array(purgeHistory.prefix(Self.maxPurgeHistory))
            }

            statusMessage = "Memory purge complete. Freed \(ByteFormatter.format(freed))."
        } catch {
            statusMessage = "Memory purge failed: \(error.localizedDescription)"
        }

        isPurging = false
    }
}
