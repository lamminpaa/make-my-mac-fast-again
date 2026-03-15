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

@Suite("AppSettings Tests")
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
