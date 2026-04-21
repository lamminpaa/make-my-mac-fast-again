import Foundation
import Darwin
import os

@MainActor
final class CPUMonitor {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "monitoring")
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
            logger.error("host_processor_info failed with kern_return_t \(result)")
            return stats
        }

        let size = Int(numCPUInfo) * MemoryLayout<integer_t>.stride
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(size)) }

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
            // Guard against counter wraparound: if any current value is less than
            // the previous value, skip this sample and just update previousTicks.
            if totalUser < prev.user || totalSystem < prev.system ||
               totalIdle < prev.idle || totalNice < prev.nice {
                previousTicks = (user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice)
                return stats
            }

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

        logger.debug("CPU read: user=\(stats.userPercentage, format: .fixed(precision: 1))% system=\(stats.systemPercentage, format: .fixed(precision: 1))% idle=\(stats.idlePercentage, format: .fixed(precision: 1))%")
        return stats
    }

    /// Reads 1/5/15-minute load averages via BSD `getloadavg(3)`.
    /// Returns zeros on failure (no entitlements or special permissions needed).
    func readLoad() -> LoadStats {
        var stats = LoadStats()
        stats.activeProcessorCount = Foundation.ProcessInfo.processInfo.activeProcessorCount

        var values = [Double](repeating: 0, count: 3)
        let count = getloadavg(&values, Int32(values.count))

        if count >= 1 { stats.oneMinute = values[0] }
        if count >= 2 { stats.fiveMinutes = values[1] }
        if count >= 3 { stats.fifteenMinutes = values[2] }

        if count < 0 {
            logger.error("getloadavg failed (returned \(count))")
        }
        return stats
    }
}
