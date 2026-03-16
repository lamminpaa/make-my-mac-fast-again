import Foundation
import Darwin
import os

@MainActor
final class MemoryMonitor {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "monitoring")

    func read() -> MemoryStats {
        var stats = MemoryStats()

        stats.total = Foundation.ProcessInfo.processInfo.physicalMemory

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            logger.error("host_statistics64 failed with kern_return_t \(result)")
            return stats
        }

        let pageSize = UInt64(getpagesize())

        stats.active = UInt64(vmStats.active_count) * pageSize
        stats.inactive = UInt64(vmStats.inactive_count) * pageSize
        stats.wired = UInt64(vmStats.wire_count) * pageSize
        stats.compressed = UInt64(vmStats.compressor_page_count) * pageSize
        stats.free = UInt64(vmStats.free_count) * pageSize

        // Match Activity Monitor: used = active + wired + compressed
        // Inactive pages are cached but immediately reclaimable, not truly "used"
        stats.used = stats.active + stats.wired + stats.compressed

        logger.debug("Memory read: used=\(stats.used) free=\(stats.free) total=\(stats.total)")
        return stats
    }
}
