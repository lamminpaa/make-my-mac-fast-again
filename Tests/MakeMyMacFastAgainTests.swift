import Testing
@testable import MakeMyMacFastAgain

@Suite("ByteFormatter Tests")
struct ByteFormatterTests {
    @Test("Formats kilobytes correctly")
    func formatBytes() {
        let result = ByteFormatter.format(1024)
        #expect(result.contains("KB") || result.contains("kB"))
    }

    @Test("Formats megabytes correctly")
    func formatMegabytes() {
        let result = ByteFormatter.format(1_048_576)
        #expect(result.contains("MB"))
    }

    @Test("Formats gigabytes correctly")
    func formatGigabytes() {
        let result = ByteFormatter.format(1_073_741_824)
        #expect(result.contains("GB"))
    }

    @Test("Formats zero bytes")
    func formatZero() {
        let result = ByteFormatter.format(0)
        #expect(result.localizedCaseInsensitiveContains("zero") || result.contains("0"))
    }

    @Test("Formats percentage correctly")
    func formatPercentage() {
        let result = ByteFormatter.formatPercentage(75.5)
        #expect(result == "75.5%")
    }

    @Test("Formats rate correctly")
    func formatRate() {
        let result = ByteFormatter.formatRate(1024)
        #expect(result == "1.0 KB/s")
    }

    @Test("Formats high rate correctly")
    func formatHighRate() {
        let result = ByteFormatter.formatRate(1_048_576)
        #expect(result == "1.0 MB/s")
    }
}

@Suite("CPU Monitor Tests")
struct CPUMonitorTests {
    @Test("Reads CPU stats")
    @MainActor
    func readCPUStats() {
        let monitor = CPUMonitor()
        _ = monitor.read()
        let stats = monitor.read()
        #expect(stats.userPercentage >= 0)
        #expect(stats.systemPercentage >= 0)
        #expect(stats.totalUsage >= 0)
    }
}

@Suite("Memory Monitor Tests")
struct MemoryMonitorTests {
    @Test("Reads memory stats")
    @MainActor
    func readMemoryStats() {
        let monitor = MemoryMonitor()
        let stats = monitor.read()
        #expect(stats.total > 0)
        #expect(stats.used > 0)
        #expect(stats.usagePercentage > 0)
        #expect(stats.usagePercentage <= 100)
    }
}

@Suite("Disk Monitor Tests")
struct DiskMonitorTests {
    @Test("Reads disk stats")
    @MainActor
    func readDiskStats() {
        let monitor = DiskMonitor()
        let stats = monitor.read()
        #expect(stats.totalSpace > 0)
        #expect(stats.freeSpace > 0)
        #expect(stats.usagePercentage > 0)
        #expect(stats.usagePercentage < 100)
    }
}

@Suite("Network Monitor Tests")
struct NetworkMonitorTests {
    @Test("Reads network stats")
    @MainActor
    func readNetworkStats() {
        let monitor = NetworkMonitor()
        let stats = monitor.read()
        #expect(stats.bytesIn >= 0)
        #expect(stats.bytesOut >= 0)
    }
}

@Suite("NavigationItem Tests")
struct NavigationItemTests {
    @Test("All items have a section")
    func allItemsHaveSection() {
        for item in NavigationItem.allCases {
            #expect(!item.section.rawValue.isEmpty)
        }
    }

    @Test("All items have system image")
    func allItemsHaveSystemImage() {
        for item in NavigationItem.allCases {
            #expect(!item.systemImage.isEmpty)
        }
    }

    @Test("Dashboard is in overview section")
    func dashboardSection() {
        #expect(NavigationItem.dashboard.section == .overview)
    }

    @Test("Eight features total")
    func featureCount() {
        #expect(NavigationItem.allCases.count == 8)
    }
}

@Suite("AppVersion Tests")
struct AppVersionTests {
    @Test("Version string is non-empty")
    func versionIsNonEmpty() {
        #expect(!AppVersion.version.isEmpty)
    }

    @Test("Build string is non-empty")
    func buildIsNonEmpty() {
        #expect(!AppVersion.build.isEmpty)
    }

    @Test("Full version contains version number")
    func fullVersionContainsVersion() {
        #expect(AppVersion.fullVersion.contains(AppVersion.version))
    }

    @Test("Short version contains version and build")
    func shortVersionFormat() {
        #expect(AppVersion.shortVersion.contains(AppVersion.version))
        #expect(AppVersion.shortVersion.contains(AppVersion.build))
    }
}

@Suite("ProcessService Tests")
struct ProcessServiceTests {
    @Test("Lists processes")
    @MainActor
    func listProcesses() {
        let service = ProcessService()
        let processes = service.listProcesses()
        #expect(!processes.isEmpty)
    }

    @Test("Processes have names")
    @MainActor
    func processesHaveNames() {
        let service = ProcessService()
        let processes = service.listProcesses()
        let namedProcesses = processes.filter { !$0.name.isEmpty }
        #expect(!namedProcesses.isEmpty)
    }
}

@Suite("Cache Cleaner Tests")
struct CacheCleanerTests {
    @Test("CacheCleanupCommand defaults timeout to 60s")
    func cleanupCommandDefaultTimeout() {
        let cmd = CacheCleanupCommand(executable: "/usr/bin/xcrun", arguments: ["simctl"])
        #expect(cmd.timeout == 60)
    }

    @Test("CacheCategory defaults cleanupCommand to nil (path-based cleanup)")
    func categoryDefaultsToPathCleanup() {
        let category = CacheCategory(
            name: "Test",
            description: "",
            paths: ["/tmp/nonexistent"],
            requiresAdmin: false
        )
        #expect(category.cleanupCommand == nil)
    }

    @Test("CacheCategory accepts cleanupCommand override")
    func categoryAcceptsCustomCleanup() {
        let command = CacheCleanupCommand(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "delete", "unavailable"],
            timeout: 120
        )
        let category = CacheCategory(
            name: "iOS Sims",
            description: "",
            paths: ["/tmp/x"],
            requiresAdmin: false,
            cleanupCommand: command
        )
        #expect(category.cleanupCommand?.executable == "/usr/bin/xcrun")
        #expect(category.cleanupCommand?.arguments == ["simctl", "delete", "unavailable"])
        #expect(category.cleanupCommand?.timeout == 120)
    }

    @Test("Default categories include iOS simulator cleanup wired to xcrun simctl")
    @MainActor
    func defaultCategoriesIncludeIOSSimulators() {
        let vm = CacheCleanerViewModel()
        vm.loadCategories()
        let sim = vm.categories.first { $0.name.contains("iOS Simulators") }
        #expect(sim != nil)
        #expect(sim?.cleanupCommand?.executable == "/usr/bin/xcrun")
        #expect(sim?.cleanupCommand?.arguments == ["simctl", "delete", "unavailable"])
        #expect(sim?.requiresAdmin == false)
    }
}
