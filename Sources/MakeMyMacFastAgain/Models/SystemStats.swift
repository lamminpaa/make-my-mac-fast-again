import Foundation

struct CPUStats: Sendable {
    var userPercentage: Double = 0
    var systemPercentage: Double = 0
    var idlePercentage: Double = 100
    var totalUsage: Double { userPercentage + systemPercentage }
}

struct MemoryStats: Sendable {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var free: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct DiskStats: Sendable {
    var totalSpace: UInt64 = 0
    var freeSpace: UInt64 = 0
    var usedSpace: UInt64 { totalSpace > freeSpace ? totalSpace - freeSpace : 0 }
    var usagePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

struct NetworkStats: Sendable {
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
    var rateIn: Double = 0
    var rateOut: Double = 0
}

struct AppProcessInfo: Identifiable, Sendable {
    let id: pid_t
    let pid: pid_t
    let name: String
    let user: String
    var cpuUsage: Double
    var memoryBytes: UInt64
    var status: String
}

struct CacheCategory: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let description: String
    let paths: [String]
    var size: UInt64 = 0
    var isSelected: Bool = true
    let requiresAdmin: Bool
}

struct BrowserProfile: Identifiable, Sendable {
    let id = UUID()
    let browser: String
    let cachePaths: [String]
    let cookiePaths: [String]
    var cacheSize: UInt64 = 0
    var isInstalled: Bool = false
}

struct StartupItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let label: String
    var isEnabled: Bool
    let type: StartupItemType
}

enum StartupItemType: String, Sendable {
    case userAgent = "User Agent"
    case globalAgent = "Global Agent"
    case globalDaemon = "Global Daemon"
}

struct LargeFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let path: String
    let name: String
    let size: UInt64
    let modifiedDate: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: LargeFile, rhs: LargeFile) -> Bool {
        lhs.path == rhs.path
    }
}
