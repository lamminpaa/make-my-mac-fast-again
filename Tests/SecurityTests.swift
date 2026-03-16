import Testing
@testable import MakeMyMacFastAgain

// MARK: - PrivilegedExecutor Tests

@Suite("PrivilegedExecutor Tests")
struct PrivilegedExecutorTests {
    let executor = PrivilegedExecutor()

    @Test("Valid cache path under /Library/Caches builds command successfully")
    func validCachePathLibrary() throws {
        let command = try executor.buildShellCommand(.removeCache(path: "/Library/Caches/test"))
        #expect(command.contains("rm -rf"))
        #expect(command.contains("/Library/Caches/test"))
    }

    @Test("Valid cache path with tilde builds command successfully")
    func validCachePathUserLibrary() throws {
        let command = try executor.buildShellCommand(.removeCache(path: "~/Library/Caches/SomeApp"))
        #expect(command.contains("rm -rf"))
        #expect(command.contains("Library/Caches/SomeApp"))
    }

    @Test("Invalid cache path outside allowed prefixes throws invalidCachePath")
    func invalidCachePathOutsideAllowed() {
        #expect(throws: PrivilegedExecutor.PrivilegedError.self) {
            try executor.buildShellCommand(.removeCache(path: "/Users/someone"))
        }
    }

    @Test("Path traversal in cache path throws invalidCachePath")
    func pathTraversalThrows() {
        #expect(throws: PrivilegedExecutor.PrivilegedError.self) {
            try executor.buildShellCommand(.removeCache(path: "/Library/Caches/../../../etc"))
        }
    }

    @Test("Valid launchctl command with system domain builds successfully")
    func validLaunchctlSystem() throws {
        let command = try executor.buildShellCommand(
            .launchctl(action: .disable, domain: "system", label: "com.example.agent")
        )
        #expect(command == "launchctl disable system/com.example.agent")
    }

    @Test("Valid launchctl command with gui domain builds successfully")
    func validLaunchctlGUI() throws {
        let command = try executor.buildShellCommand(
            .launchctl(action: .enable, domain: "gui/501", label: "com.example.helper")
        )
        #expect(command == "launchctl enable gui/501/com.example.helper")
    }

    @Test("Invalid launchctl domain throws invalidLaunchctlDomain")
    func invalidLaunchctlDomain() {
        #expect(throws: PrivilegedExecutor.PrivilegedError.self) {
            try executor.buildShellCommand(
                .launchctl(action: .disable, domain: "user", label: "com.example.agent")
            )
        }
    }

    @Test("Launchctl label with spaces throws invalidLaunchctlLabel")
    func labelWithSpacesThrows() {
        #expect(throws: PrivilegedExecutor.PrivilegedError.self) {
            try executor.buildShellCommand(
                .launchctl(action: .disable, domain: "system", label: "com.bad label")
            )
        }
    }

    @Test("Launchctl label with semicolons throws invalidLaunchctlLabel")
    func labelWithSemicolonsThrows() {
        #expect(throws: PrivilegedExecutor.PrivilegedError.self) {
            try executor.buildShellCommand(
                .launchctl(action: .disable, domain: "system", label: "com.bad;rm -rf /")
            )
        }
    }

    @Test("Empty launchctl label throws invalidLaunchctlLabel")
    func emptyLabelThrows() {
        #expect(throws: PrivilegedExecutor.PrivilegedError.self) {
            try executor.buildShellCommand(
                .launchctl(action: .disable, domain: "system", label: "")
            )
        }
    }

    @Test("Flush DNS command builds correctly")
    func flushDNSCommand() throws {
        let command = try executor.buildShellCommand(.flushDNS)
        #expect(command == "killall -HUP mDNSResponder")
    }

    @Test("Purge memory command builds correctly")
    func purgeMemoryCommand() throws {
        let command = try executor.buildShellCommand(.purgeMemory)
        #expect(command == "/usr/sbin/purge")
    }
}

// MARK: - ProcessManager Safety Tests

@Suite("ProcessManager Safety Tests")
struct ProcessManagerSafetyTests {
    @Test("Own PID is marked as protected in process list")
    @MainActor
    func ownPIDIsProtected() {
        let appState = AppState()
        let vm = ProcessManagerViewModel()
        vm.bind(to: appState)
        vm.refresh()

        // The ProcessManagerViewModel stores its own PID internally via getpid().
        // Find a process marked as protected that is neither PID 0, PID 1, nor kernel_task.
        // This must be the app's own process.
        let selfProtected = vm.processes.filter {
            $0.isProtected && $0.pid != 0 && $0.pid != 1 && $0.name != "kernel_task"
        }
        #expect(!selfProtected.isEmpty,
                "At least the own process must be marked as protected")
    }

    @Test("PID 0 is protected if present")
    @MainActor
    func pid0IsProtected() {
        let appState = AppState()
        let vm = ProcessManagerViewModel()
        vm.bind(to: appState)
        vm.refresh()

        let pid0Process = vm.processes.first { $0.pid == 0 }
        if let p = pid0Process {
            #expect(p.isProtected == true, "PID 0 must be marked as protected")
        }
    }

    @Test("PID 1 (launchd) is protected if present")
    @MainActor
    func pid1IsProtected() {
        let appState = AppState()
        let vm = ProcessManagerViewModel()
        vm.bind(to: appState)
        vm.refresh()

        let pid1Process = vm.processes.first { $0.pid == 1 }
        if let p = pid1Process {
            #expect(p.isProtected == true, "PID 1 (launchd) must be marked as protected")
        }
    }

    @Test("Process list is non-empty after refresh")
    @MainActor
    func processListNonEmpty() {
        let appState = AppState()
        let vm = ProcessManagerViewModel()
        vm.bind(to: appState)
        vm.refresh()

        #expect(!vm.processes.isEmpty, "Process list should not be empty after refresh")
    }
}

// MARK: - AppSettings Tests

@Suite("AppSettings Tests", .serialized)
struct AppSettingsTests {
    @Test("Load with no stored data returns defaults")
    func loadReturnsDefaults() {
        AppSettings.clearStorage()
        let settings = AppSettings.load()
        #expect(settings.dashboardRefreshInterval == 2.0)
        #expect(settings.processRefreshInterval == 3.0)
        #expect(settings.confirmBeforeCleanup == true)
        #expect(settings.confirmBeforeKillProcess == true)
    }

    @Test("Save and load roundtrips correctly")
    func saveLoadRoundtrip() {
        AppSettings.clearStorage()
        var settings = AppSettings()
        settings.dashboardRefreshInterval = 5.0
        settings.processRefreshInterval = 10.0
        settings.confirmBeforeCleanup = false
        settings.confirmBeforeKillProcess = false
        settings.save()

        let loaded = AppSettings.load()
        #expect(loaded.dashboardRefreshInterval == 5.0)
        #expect(loaded.processRefreshInterval == 10.0)
        #expect(loaded.confirmBeforeCleanup == false)
        #expect(loaded.confirmBeforeKillProcess == false)

        // Clean up
        AppSettings.clearStorage()
    }

    @Test("Default refresh intervals are positive")
    func defaultIntervalsArePositive() {
        let settings = AppSettings()
        #expect(settings.dashboardRefreshInterval > 0)
        #expect(settings.processRefreshInterval > 0)
    }

    @Test("Load with corrupted data returns defaults")
    func loadCorruptedDataReturnsDefaults() {
        // Write invalid data that cannot be decoded as AppSettings
        AppSettings.writeCorruptedStorage("not valid json")

        let settings = AppSettings.load()
        #expect(settings.dashboardRefreshInterval == 2.0)
        #expect(settings.processRefreshInterval == 3.0)

        // Clean up
        AppSettings.clearStorage()
    }
}

// MARK: - ShellExecutor Tests

@Suite("ShellExecutor Tests")
struct ShellExecutorTests {
    @Test("Simple echo command returns expected output")
    func echoCommand() async throws {
        let shell = ShellExecutor()
        let result = try await shell.run("echo hello")
        #expect(result.output == "hello")
        #expect(result.exitCode == 0)
        #expect(result.succeeded == true)
    }

    @Test("Failing command returns non-zero exit code")
    func failingCommand() async throws {
        let shell = ShellExecutor()
        let result = try await shell.run("exit 42")
        #expect(result.exitCode == 42)
        #expect(result.succeeded == false)
    }

    @Test("Timeout kills long-running command")
    func timeoutKillsLongCommand() async {
        let shell = ShellExecutor()
        do {
            _ = try await shell.run("sleep 30", timeout: 1)
            Issue.record("Expected ShellError.timeout to be thrown")
        } catch let error as ShellError {
            switch error {
            case .timeout(let seconds, _):
                #expect(seconds == 1)
            default:
                Issue.record("Expected ShellError.timeout, got \(error)")
            }
        } catch {
            Issue.record("Expected ShellError.timeout, got \(error)")
        }
    }

    @Test("Executable not found throws executableNotFound")
    func executableNotFound() async {
        let shell = ShellExecutor()
        do {
            _ = try await shell.run(executablePath: "/nonexistent/binary")
            Issue.record("Expected ShellError.executableNotFound to be thrown")
        } catch let error as ShellError {
            switch error {
            case .executableNotFound(let path):
                #expect(path == "/nonexistent/binary")
            default:
                Issue.record("Expected ShellError.executableNotFound, got \(error)")
            }
        } catch {
            Issue.record("Expected ShellError.executableNotFound, got \(error)")
        }
    }

    @Test("Command captures stderr output")
    func stderrCapture() async throws {
        let shell = ShellExecutor()
        let result = try await shell.run("echo error_msg >&2")
        #expect(result.errorOutput == "error_msg")
    }
}

// MARK: - Health Score Tests

@Suite("Health Score Tests")
struct HealthScoreTests {
    @Test("Health score is in valid range 0-100")
    @MainActor
    func scoreInValidRange() {
        let state = AppState()
        let score = state.healthScore
        #expect(score >= 0 && score <= 100)
    }

    @Test("Healthy system scores above 60")
    @MainActor
    func healthySystemScoresWell() {
        let state = AppState()
        // Low usage = healthy
        state.diskStats = DiskStats(totalSpace: 1_000_000_000_000, freeSpace: 700_000_000_000)
        state.memoryStats = MemoryStats(total: 16_000_000_000, used: 6_000_000_000)
        state.zombieProcessCount = 0
        state.enabledHighImpactStartupItems = 2
        state.totalEnabledStartupItems = 5
        state.totalCacheBytes = 500_000_000 // 500 MB on 1 TB = 0.05%
        let score = state.healthScore
        #expect(score >= 60, "Healthy system should score above 60, got \(score)")
    }

    @Test("Stressed system scores below 50")
    @MainActor
    func stressedSystemScoresLow() {
        let state = AppState()
        // High usage = stressed
        state.diskStats = DiskStats(totalSpace: 500_000_000_000, freeSpace: 25_000_000_000) // 95% full
        state.memoryStats = MemoryStats(total: 8_000_000_000, used: 7_600_000_000) // 95% used
        state.zombieProcessCount = 10
        state.enabledHighImpactStartupItems = 10
        state.totalEnabledStartupItems = 15
        state.totalCacheBytes = 30_000_000_000 // 6% of disk
        let score = state.healthScore
        #expect(score < 50, "Stressed system should score below 50, got \(score)")
    }

    @Test("Zombie penalty is gradual with softened multiplier")
    @MainActor
    func zombiePenaltyIsGradual() {
        let state = AppState()
        state.diskStats = DiskStats(totalSpace: 1_000_000_000_000, freeSpace: 700_000_000_000)
        state.memoryStats = MemoryStats(total: 16_000_000_000, used: 6_000_000_000)
        state.totalEnabledStartupItems = 1
        state.enabledHighImpactStartupItems = 0
        state.totalCacheBytes = 100_000_000

        // No zombies
        state.zombieProcessCount = 0
        let scoreNoZombies = state.healthScore

        // 5 zombies — should reduce score slightly, not drastically
        state.zombieProcessCount = 5
        let score5Zombies = state.healthScore

        let difference = scoreNoZombies - score5Zombies
        // 5 zombies * 5 per zombie = 25 reduction in zombie sub-score
        // Zombie weight is 10%, so impact should be ~2-3 points total
        #expect(difference > 0, "Zombies should reduce score")
        #expect(difference < 10, "5 zombies should not reduce score by more than 10, got \(difference)")
    }

    @Test("Startup score uses real data when items are scanned")
    @MainActor
    func startupScoreUsesRealData() {
        let state = AppState()
        state.diskStats = DiskStats(totalSpace: 1_000_000_000_000, freeSpace: 700_000_000_000)
        state.memoryStats = MemoryStats(total: 16_000_000_000, used: 6_000_000_000)
        state.zombieProcessCount = 0
        state.totalCacheBytes = 100_000_000

        // No startup items scanned yet — neutral
        state.totalEnabledStartupItems = 0
        state.enabledHighImpactStartupItems = 0
        let scoreNoData = state.healthScore

        // Many high-impact items — should lower score
        state.totalEnabledStartupItems = 15
        state.enabledHighImpactStartupItems = 10
        let scoreManyItems = state.healthScore

        #expect(scoreManyItems < scoreNoData,
                "Many high-impact startup items should lower score")
    }

    @Test("Cache score responds to cache size relative to disk")
    @MainActor
    func cacheScoreRespondsToSize() {
        let state = AppState()
        state.diskStats = DiskStats(totalSpace: 1_000_000_000_000, freeSpace: 700_000_000_000)
        state.memoryStats = MemoryStats(total: 16_000_000_000, used: 6_000_000_000)
        state.zombieProcessCount = 0
        state.totalEnabledStartupItems = 1
        state.enabledHighImpactStartupItems = 0

        // Small cache = good score
        state.totalCacheBytes = 1_000_000_000 // 1 GB = 0.1% of 1 TB
        let scoreSmallCache = state.healthScore

        // Large cache = worse score
        state.totalCacheBytes = 60_000_000_000 // 60 GB = 6% of 1 TB
        let scoreLargeCache = state.healthScore

        #expect(scoreSmallCache > scoreLargeCache,
                "Larger cache should result in lower health score")
    }
}
