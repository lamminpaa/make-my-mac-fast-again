import Foundation
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

    @Test("Nine features total")
    func featureCount() {
        #expect(NavigationItem.allCases.count == 9)
    }

    @Test("Zombie Pollers is in the system section")
    func zombiePollersSection() {
        #expect(NavigationItem.zombiePollers.section == .system)
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

@Suite("Parent Chain Tests")
struct ParentChainTests {
    private func makeProcess(
        pid: pid_t,
        ppid: pid_t,
        name: String,
        commandLine: String = ""
    ) -> AppProcessInfo {
        AppProcessInfo(
            id: pid,
            pid: pid,
            ppid: ppid,
            name: name,
            user: "test",
            cpuUsage: 0,
            memoryBytes: 0,
            status: "R",
            startTime: 0,
            commandLine: commandLine
        )
    }

    @Test("ancestors walks chain from nearest parent to root")
    @MainActor
    func walksChainNearestFirst() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 100, ppid: 1, name: "launchd-child"),
            makeProcess(pid: 200, ppid: 100, name: "zsh"),
            makeProcess(pid: 300, ppid: 200, name: "python", commandLine: "python loop.py"),
        ])

        let chain = vm.ancestors(of: 300)
        #expect(chain.map(\.pid) == [200, 100])
        #expect(chain.first?.name == "zsh")
    }

    @Test("ancestors stops at PID 1 (launchd)")
    @MainActor
    func stopsAtLaunchd() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 500, ppid: 1, name: "safari"),
        ])

        let chain = vm.ancestors(of: 500)
        #expect(chain.isEmpty)
    }

    @Test("ancestors stops at missing parent")
    @MainActor
    func stopsAtMissingParent() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 42, ppid: 9999, name: "orphan"),
        ])

        let chain = vm.ancestors(of: 42)
        #expect(chain.isEmpty)
    }

    @Test("ancestors guards against self-cycle")
    @MainActor
    func guardsSelfCycle() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 50, ppid: 50, name: "self-loop"),
        ])

        let chain = vm.ancestors(of: 50)
        #expect(chain.isEmpty)
    }

    @Test("ancestors guards against A→B→A cycle")
    @MainActor
    func guardsMutualCycle() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 10, ppid: 20, name: "a"),
            makeProcess(pid: 20, ppid: 10, name: "b"),
        ])

        let chain = vm.ancestors(of: 10)
        #expect(chain.map(\.pid) == [20])
    }

    @Test("ancestors includingSelf prepends the starting process")
    @MainActor
    func includingSelfPrependsStart() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 100, ppid: 1, name: "parent"),
            makeProcess(pid: 200, ppid: 100, name: "child"),
        ])

        let chain = vm.ancestors(of: 200, includingSelf: true)
        #expect(chain.map(\.pid) == [200, 100])
    }

    @Test("parentTree sort groups children directly under their parent")
    @MainActor
    func parentTreeSortGroupsChildren() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 100, ppid: 1, name: "alpha-parent"),
            makeProcess(pid: 200, ppid: 1, name: "beta-parent"),
            makeProcess(pid: 101, ppid: 100, name: "alpha-child-one"),
            makeProcess(pid: 102, ppid: 100, name: "alpha-child-two"),
            makeProcess(pid: 201, ppid: 200, name: "beta-child"),
        ])
        vm.sortOrder = .parentTree
        vm.selectedFilter = .allProcesses

        let order = vm.filteredProcesses.map(\.pid)
        #expect(order == [100, 101, 102, 200, 201])
    }

    @Test("parentTree sort places grandchildren under their parent subtree")
    @MainActor
    func parentTreeSortKeepsSubtreesContiguous() {
        let vm = ProcessManagerViewModel()
        vm._seedProcesses([
            makeProcess(pid: 10, ppid: 1, name: "root-a"),
            makeProcess(pid: 20, ppid: 10, name: "child-a"),
            makeProcess(pid: 30, ppid: 20, name: "grandchild-a"),
            makeProcess(pid: 40, ppid: 1, name: "root-b"),
        ])
        vm.sortOrder = .parentTree

        let order = vm.filteredProcesses.map(\.pid)
        let aIndex = order.firstIndex(of: 10)!
        let aChildIndex = order.firstIndex(of: 20)!
        let aGrandIndex = order.firstIndex(of: 30)!
        let bIndex = order.firstIndex(of: 40)!

        #expect(aIndex < aChildIndex)
        #expect(aChildIndex < aGrandIndex)
        #expect(aGrandIndex < bIndex)
    }
}

@Suite("Load Average Tests")
struct LoadAverageTests {
    @Test("getloadavg returns non-negative values")
    @MainActor
    func readLoadIsNonNegative() {
        let monitor = CPUMonitor()
        let stats = monitor.readLoad()
        #expect(stats.oneMinute >= 0)
        #expect(stats.fiveMinutes >= 0)
        #expect(stats.fifteenMinutes >= 0)
    }

    @Test("Active processor count reflects the running host")
    @MainActor
    func activeProcessorCountMatchesHost() {
        let monitor = CPUMonitor()
        let stats = monitor.readLoad()
        #expect(stats.activeProcessorCount == ProcessInfo.processInfo.activeProcessorCount)
        #expect(stats.activeProcessorCount >= 1)
    }

    @Test("Load ratio defaults to zero on zero cores (guard)")
    func loadRatioZeroCoresIsZero() {
        var stats = LoadStats()
        stats.oneMinute = 5.0
        stats.activeProcessorCount = 0
        #expect(stats.loadRatio == 0)
    }

    @Test("Load ratio scales with core count")
    func loadRatioScalesInverselyWithCores() {
        var stats = LoadStats()
        stats.oneMinute = 8.0
        stats.activeProcessorCount = 4
        #expect(stats.loadRatio == 2.0)
        stats.activeProcessorCount = 8
        #expect(stats.loadRatio == 1.0)
    }

    @Test("Formatted load string uses two decimal places")
    func formatLoadTwoDecimals() {
        #expect(LoadCard.formatLoad(0) == "0.00")
        #expect(LoadCard.formatLoad(1.2345) == "1.23")
        #expect(LoadCard.formatLoad(152.47) == "152.47")
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

@Suite("Zombie Poller Detector Tests")
struct ZombiePollerDetectorTests {
    private func makeProc(
        pid: pid_t,
        ppid: pid_t,
        name: String,
        commandLine: String,
        ageSeconds: TimeInterval = 3600,
        now: Date = Date()
    ) -> AppProcessInfo {
        AppProcessInfo(
            id: pid,
            pid: pid,
            ppid: ppid,
            name: name,
            user: "kalle",
            cpuUsage: 0,
            cpuPercentage: 0,
            memoryBytes: 0,
            status: "Running",
            isProtected: false,
            startTime: Int64(now.timeIntervalSince1970 - ageSeconds),
            commandLine: commandLine
        )
    }

    @Test("Recognizes while-sleep shell loop")
    func matchesWhileSleepLoop() {
        #expect(
            ZombiePollerDetector.commandLineMatchesLoop(
                "/bin/zsh -c while true; do kubectl get pods; sleep 2; done"
            )
        )
    }

    @Test("Recognizes until-sleep shell loop")
    func matchesUntilSleepLoop() {
        #expect(
            ZombiePollerDetector.commandLineMatchesLoop(
                "sh -c until curl -f http://localhost; do sleep 5; done"
            )
        )
    }

    @Test("Does not match a one-shot command without a loop")
    func ignoresOneShot() {
        #expect(
            !ZombiePollerDetector.commandLineMatchesLoop(
                "/bin/zsh -c 'git status && npm install'"
            )
        )
    }

    @Test("Does not match an empty command line (system process)")
    func ignoresEmptyCommand() {
        #expect(!ZombiePollerDetector.commandLineMatchesLoop(""))
    }

    @Test("isCandidateShell requires a -c flag")
    func candidateShellRequiresDashC() {
        let loop = AppProcessInfo(
            id: 100, pid: 100, ppid: 1, name: "zsh", user: "kalle",
            cpuUsage: 0, memoryBytes: 0, status: "Running",
            commandLine: "/bin/zsh -c while true; do :; sleep 2; done"
        )
        let interactive = AppProcessInfo(
            id: 101, pid: 101, ppid: 1, name: "zsh", user: "kalle",
            cpuUsage: 0, memoryBytes: 0, status: "Running",
            commandLine: "/bin/zsh -i"
        )
        #expect(ZombiePollerDetector.isCandidateShell(loop))
        #expect(!ZombiePollerDetector.isCandidateShell(interactive))
    }

    @Test("isCandidateShell rejects non-shell processes")
    func candidateShellRejectsNonShell() {
        let python = AppProcessInfo(
            id: 102, pid: 102, ppid: 1, name: "python3", user: "kalle",
            cpuUsage: 0, memoryBytes: 0, status: "Running",
            commandLine: "python3 -c while True: pass"
        )
        #expect(!ZombiePollerDetector.isCandidateShell(python))
    }

    @Test("isCandidateShell rejects shell-adjacent names that contain a shell word")
    func candidateShellRejectsShellAdjacent() {
        let preexec = AppProcessInfo(
            id: 103, pid: 103, ppid: 1, name: "bash-preexec", user: "kalle",
            cpuUsage: 0, memoryBytes: 0, status: "Running",
            commandLine: "bash-preexec -c while true; do :; done"
        )
        #expect(!ZombiePollerDetector.isCandidateShell(preexec))
    }

    @Test("Does not match a reversed sleep-then-while command")
    func ignoresReversedOrder() {
        // In a real `sh -c` loop the keyword always precedes `sleep`. Reversed
        // ordering only shows up in unrelated commands.
        #expect(
            !ZombiePollerDetector.commandLineMatchesLoop(
                "sh -c sleep 2 && while_helper --once"
            )
        )
    }

    @Test("Counts distinct child PIDs across sliding window")
    func distinctChildCountAcrossWindow() {
        let window: [Set<pid_t>] = [
            [200, 201],
            [202],
            [203, 204],
            []
        ]
        #expect(ZombiePollerDetector.distinctChildCount(in: window) == 5)
    }

    @Test("Single long-lived child contributes only one to distinct count")
    func longLivedChildCounts() {
        let window: [Set<pid_t>] = Array(repeating: Set([300]), count: 20)
        #expect(ZombiePollerDetector.distinctChildCount(in: window) == 1)
    }

    @Test("Detector flags a shell that keeps spawning new children")
    @MainActor
    func detectsRunawayLoop() {
        let detector = ZombiePollerDetector()
        let now = Date()
        let parentPID: pid_t = 5000
        let shell = makeProc(
            pid: parentPID, ppid: 1, name: "zsh",
            commandLine: "/bin/zsh -c while true; do date; sleep 2; done",
            ageSeconds: 3600, now: now
        )

        // Feed three ticks, each with a different child PID under the same parent.
        for childPID: pid_t in [9001, 9002, 9003] {
            let child = makeProc(
                pid: childPID, ppid: parentPID, name: "date",
                commandLine: "date",
                ageSeconds: 1, now: now
            )
            _ = detector.ingest(processes: [shell, child], now: now)
        }

        let results = detector.ingest(processes: [shell], now: now)
        #expect(results.count == 1)
        #expect(results.first?.pid == parentPID)
        #expect(results.first?.shell == "zsh")
    }

    @Test("Detector does not flag a legitimate build pipeline (no loop pattern)")
    @MainActor
    func doesNotFlagOneShotPipeline() {
        let detector = ZombiePollerDetector()
        let now = Date()
        let parentPID: pid_t = 5100
        let shell = makeProc(
            pid: parentPID, ppid: 1, name: "bash",
            commandLine: "/bin/bash -c 'make && make test'",
            ageSeconds: 3600, now: now
        )

        for childPID: pid_t in [9101, 9102, 9103, 9104] {
            let child = makeProc(
                pid: childPID, ppid: parentPID, name: "cc",
                commandLine: "cc -c foo.c",
                ageSeconds: 1, now: now
            )
            _ = detector.ingest(processes: [shell, child], now: now)
        }

        let results = detector.ingest(processes: [shell], now: now)
        #expect(results.isEmpty)
    }

    @Test("Detector respects the minimum age gate")
    @MainActor
    func respectsAgeGate() {
        let detector = ZombiePollerDetector()
        let now = Date()
        let parentPID: pid_t = 5200
        // Only 10 seconds old — below the 60s threshold.
        let shell = makeProc(
            pid: parentPID, ppid: 1, name: "zsh",
            commandLine: "/bin/zsh -c while true; do :; sleep 1; done",
            ageSeconds: 10, now: now
        )

        for childPID: pid_t in [9201, 9202, 9203] {
            let child = makeProc(
                pid: childPID, ppid: parentPID, name: "sleep",
                commandLine: "sleep 1",
                ageSeconds: 1, now: now
            )
            _ = detector.ingest(processes: [shell, child], now: now)
        }

        let results = detector.ingest(processes: [shell], now: now)
        #expect(results.isEmpty)
    }

    @Test("Ignored PIDs are excluded from results")
    @MainActor
    func respectsIgnoredPIDs() {
        let detector = ZombiePollerDetector()
        let now = Date()
        let parentPID: pid_t = 5300
        let shell = makeProc(
            pid: parentPID, ppid: 1, name: "zsh",
            commandLine: "/bin/zsh -c while true; do :; sleep 2; done",
            ageSeconds: 3600, now: now
        )
        detector.ignoredPIDs.insert(parentPID)

        for childPID: pid_t in [9301, 9302, 9303] {
            _ = detector.ingest(processes: [
                shell,
                makeProc(pid: childPID, ppid: parentPID, name: "x",
                         commandLine: "x", ageSeconds: 0, now: now)
            ], now: now)
        }

        let results = detector.ingest(processes: [shell], now: now)
        #expect(results.isEmpty)
    }

    @Test("Reset clears the sliding-window history")
    @MainActor
    func resetClearsHistory() {
        let detector = ZombiePollerDetector()
        let now = Date()
        let parentPID: pid_t = 5400
        let shell = makeProc(
            pid: parentPID, ppid: 1, name: "zsh",
            commandLine: "/bin/zsh -c while true; do :; sleep 2; done",
            ageSeconds: 3600, now: now
        )
        for childPID: pid_t in [9401, 9402, 9403] {
            _ = detector.ingest(processes: [
                shell,
                makeProc(pid: childPID, ppid: parentPID, name: "x",
                         commandLine: "x", ageSeconds: 0, now: now)
            ], now: now)
        }
        detector.reset()

        // After reset, a single tick with no visible children produces no match.
        let results = detector.ingest(processes: [shell], now: now)
        #expect(results.isEmpty)
    }

    @Test("Pretty-printed command collapses whitespace runs")
    func prettyCommandNormalizesWhitespace() {
        let pretty = ZombiePollerDetector.prettyCommand(
            "  /bin/zsh    -c\twhile\ttrue;  do   :;  done "
        )
        #expect(pretty == "/bin/zsh -c while true; do :; done")
    }

    @Test("ZombiePoller.spawnsPerMinute reports zero for empty window")
    func spawnsPerMinuteEmptyWindow() {
        let poller = ZombiePoller(
            id: 1, pid: 1, ppid: 0, shell: "zsh",
            command: "x", startTime: 0, uptimeSeconds: 0,
            cpuTimeNanos: 0, recentChildSpawns: 5,
            recentChildSamples: 0
        )
        #expect(poller.spawnsPerMinute == 0)
    }

    @Test("ZombiePoller.spawnsPerMinute scales with window length")
    func spawnsPerMinuteScales() {
        // 30 spawns over 60 samples (at 2s each) = 30 spawns / 120s = 15/min
        let poller = ZombiePoller(
            id: 1, pid: 1, ppid: 0, shell: "zsh",
            command: "x", startTime: 0, uptimeSeconds: 0,
            cpuTimeNanos: 0, recentChildSpawns: 30,
            recentChildSamples: 60
        )
        #expect(abs(poller.spawnsPerMinute - 15.0) < 0.001)
    }
}

@Suite("Zombie Poller Card Tests")
struct ZombiePollerCardTests {
    @Test("formatUptime handles minutes")
    func formatMinutes() {
        #expect(ZombiePollerCard.formatUptime(180) == "3m")
    }

    @Test("formatUptime handles hours and minutes")
    func formatHours() {
        #expect(ZombiePollerCard.formatUptime(3_660) == "1h 1m")
    }

    @Test("formatUptime handles days and hours")
    func formatDays() {
        #expect(ZombiePollerCard.formatUptime(90_000) == "1d 1h")
    }

    @Test("formatUptime returns em dash for zero")
    func formatZero() {
        #expect(ZombiePollerCard.formatUptime(0) == "—")
    }
}
