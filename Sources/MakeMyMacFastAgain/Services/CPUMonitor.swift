import Foundation
import Darwin

@MainActor
final class CPUMonitor {
    private var previousTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    func read() -> CPUStats {
        var stats = CPUStats()

        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return stats
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(info[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[offset + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(info[offset + Int(CPU_STATE_NICE)])
        }

        if let prev = previousTicks {
            let deltaUser = totalUser - prev.user
            let deltaSystem = totalSystem - prev.system
            let deltaIdle = totalIdle - prev.idle
            let deltaNice = totalNice - prev.nice
            let totalDelta = deltaUser + deltaSystem + deltaIdle + deltaNice

            if totalDelta > 0 {
                stats.userPercentage = Double(deltaUser + deltaNice) / Double(totalDelta) * 100
                stats.systemPercentage = Double(deltaSystem) / Double(totalDelta) * 100
                stats.idlePercentage = Double(deltaIdle) / Double(totalDelta) * 100
            }
        }

        previousTicks = (user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice)

        let size = Int(numCPUInfo) * MemoryLayout<integer_t>.stride
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(size))

        return stats
    }
}
