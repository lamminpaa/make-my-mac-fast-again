import Foundation
import Darwin

@MainActor
final class MemoryMonitor {
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

        guard result == KERN_SUCCESS else { return stats }

        let pageSize = UInt64(getpagesize())

        stats.active = UInt64(vmStats.active_count) * pageSize
        stats.inactive = UInt64(vmStats.inactive_count) * pageSize
        stats.wired = UInt64(vmStats.wire_count) * pageSize
        stats.compressed = UInt64(vmStats.compressor_page_count) * pageSize
        stats.free = UInt64(vmStats.free_count) * pageSize

        stats.used = stats.active + stats.wired + stats.compressed + stats.inactive

        return stats
    }
}
