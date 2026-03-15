import Foundation
import SwiftUI
import os

struct PurgeHistoryEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let freed: UInt64
}

@MainActor
@Observable
final class MemoryOptimizerViewModel {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "memory-optimizer")
    var isPurging = false
    var statusMessage = ""
    var memoryBefore: UInt64 = 0
    var memoryAfter: UInt64 = 0
    var showResult = false
    var lastPurgeFreed: UInt64?
    var purgeHistory: [PurgeHistoryEntry] = []

    /// Read memoryStats from AppState; fall back to empty stats if not bound yet.
    var memoryStats: MemoryStats {
        appState?.memoryStats ?? MemoryStats()
    }

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

    private weak var appState: AppState?
    private let privilegedExecutor = PrivilegedExecutor()

    func bind(to appState: AppState) {
        self.appState = appState
    }

    func purgeMemory() async {
        isPurging = true
        showResult = false
        statusMessage = "Purging memory (requires admin)..."

        memoryBefore = memoryStats.used

        do {
            _ = try await privilegedExecutor.run(.purgeMemory)

            // Wait for memory stats to settle (AppState timer refreshes automatically)
            try? await Task.sleep(for: .seconds(2))

            memoryAfter = memoryStats.used
            showResult = true

            let freed = memoryBefore > memoryAfter ? memoryBefore - memoryAfter : 0
            lastPurgeFreed = freed

            let entry = PurgeHistoryEntry(date: Date(), freed: freed)
            purgeHistory.insert(entry, at: 0)
            if purgeHistory.count > Self.maxPurgeHistory {
                purgeHistory = Array(purgeHistory.prefix(Self.maxPurgeHistory))
            }

            logger.info("Memory purge complete. Freed \(ByteFormatter.format(freed), privacy: .public)")
            statusMessage = "Memory purge complete. Freed \(ByteFormatter.format(freed))."
        } catch {
            logger.warning("Memory purge failed: \(error.localizedDescription)")
            statusMessage = "Memory purge failed: \(error.localizedDescription)"
        }

        isPurging = false
    }
}
