import Foundation

struct CPUStats: Sendable {
    var userPercentage: Double = 0
    var systemPercentage: Double = 0
    var idlePercentage: Double = 100
    var totalUsage: Double { userPercentage + systemPercentage }
}

/// Unix-style load averages from `getloadavg(3)`.
/// Load measures the average number of runnable + uninterruptible-sleep
/// processes over 1/5/15-minute windows. Unlike CPU%, load exposes I/O-bound
/// stalls and queue depth — a system with load 10 on 4 cores is heavily
/// overloaded even if every CPU shows idle time.
struct LoadStats: Sendable {
    var oneMinute: Double = 0
    var fiveMinutes: Double = 0
    var fifteenMinutes: Double = 0
    var activeProcessorCount: Int = 1

    /// 1-minute load normalized by core count.
    /// < 0.7 = idle, 0.7-1.5 = busy, >= 1.5 = overloaded.
    var loadRatio: Double {
        guard activeProcessorCount > 0 else { return 0 }
        return oneMinute / Double(activeProcessorCount)
    }
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
    var cpuPercentage: Double = 0
    var memoryBytes: UInt64
    var status: String
    var isProtected: Bool = false
}

/// Custom cleanup command used when the default path-removal strategy does not apply
/// (e.g. iOS simulators, which must be cleaned via `xcrun simctl delete unavailable`
/// instead of `rm -rf` on the device directory).
struct CacheCleanupCommand: Sendable, Equatable {
    let executable: String
    let arguments: [String]
    let timeout: TimeInterval

    init(executable: String, arguments: [String], timeout: TimeInterval = 60) {
        self.executable = executable
        self.arguments = arguments
        self.timeout = timeout
    }
}

struct CacheCategory: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let description: String
    let paths: [String]
    var size: UInt64 = 0
    var isSelected: Bool = true
    let requiresAdmin: Bool
    /// When set, cleanup runs this command instead of removing the `paths` contents.
    /// `paths` is still used to measure size before and after.
    let cleanupCommand: CacheCleanupCommand?

    init(
        name: String,
        description: String,
        paths: [String],
        size: UInt64 = 0,
        isSelected: Bool = true,
        requiresAdmin: Bool,
        cleanupCommand: CacheCleanupCommand? = nil
    ) {
        self.name = name
        self.description = description
        self.paths = paths
        self.size = size
        self.isSelected = isSelected
        self.requiresAdmin = requiresAdmin
        self.cleanupCommand = cleanupCommand
    }
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

struct HealthScoreBreakdown: Sendable {
    let diskScore: Double
    let memoryScore: Double
    let startupScore: Double
    let cacheScore: Double
    let zombieScore: Double
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
