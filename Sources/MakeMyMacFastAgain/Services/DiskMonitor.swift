import Foundation

@MainActor
final class DiskMonitor {
    func read() -> DiskStats {
        var stats = DiskStats()

        guard let rootURL = URL(string: "file:///") else { return stats }

        do {
            let values = try rootURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])

            if let total = values.volumeTotalCapacity {
                stats.totalSpace = UInt64(total)
            }
            if let available = values.volumeAvailableCapacityForImportantUsage {
                stats.freeSpace = UInt64(available)
            }
        } catch {
            // Fallback: use FileManager
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
                if let total = attrs[.systemSize] as? UInt64 {
                    stats.totalSpace = total
                }
                if let free = attrs[.systemFreeSize] as? UInt64 {
                    stats.freeSpace = free
                }
            }
        }

        return stats
    }
}
