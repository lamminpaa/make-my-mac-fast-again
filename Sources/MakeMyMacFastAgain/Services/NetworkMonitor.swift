import Foundation
import Darwin
import os

@MainActor
final class NetworkMonitor {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "monitoring")
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTimestamp: Date?

    func read() -> NetworkStats {
        var stats = NetworkStats()

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            logger.error("getifaddrs failed")
            return stats
        }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var current = firstAddr
        while true {
            let name = String(cString: current.pointee.ifa_name)

            // Only count physical interfaces (en0, en1, etc.)
            if name.hasPrefix("en") {
                if let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = current.pointee.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self)
                        totalIn += UInt64(networkData.pointee.ifi_ibytes)
                        totalOut += UInt64(networkData.pointee.ifi_obytes)
                    }
                }
            }

            if let next = current.pointee.ifa_next {
                current = next
            } else {
                break
            }
        }

        stats.bytesIn = totalIn
        stats.bytesOut = totalOut

        if let prevTime = previousTimestamp {
            let elapsed = Date().timeIntervalSince(prevTime)
            if elapsed > 0 {
                let deltaIn = totalIn >= previousBytesIn ? totalIn - previousBytesIn : 0
                let deltaOut = totalOut >= previousBytesOut ? totalOut - previousBytesOut : 0
                stats.rateIn = Double(deltaIn) / elapsed
                stats.rateOut = Double(deltaOut) / elapsed
            }
        }

        previousBytesIn = totalIn
        previousBytesOut = totalOut
        previousTimestamp = Date()

        logger.debug("Network read: in=\(stats.bytesIn) out=\(stats.bytesOut) rateIn=\(stats.rateIn, format: .fixed(precision: 0)) rateOut=\(stats.rateOut, format: .fixed(precision: 0))")
        return stats
    }
}
