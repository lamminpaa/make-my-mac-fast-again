# Make My Mac Fast Again

Native macOS SwiftUI system optimizer and cleanup utility. Built with Swift 6.0 strict concurrency, Swift Package Manager, no Xcode IDE required.

- **Bundle ID:** `io.tunk.make-my-mac-fast-again`
- **Target:** macOS 14+ (Sonoma)
- **Swift:** 6.0 with strict concurrency checking

## Build & Run

```bash
make build      # swift build
make run        # build + run debug binary
make release    # swift build -c release
make test       # swift test
make bundle     # create .app bundle from release build
make clean      # swift package clean
```

Or directly:

```bash
swift build
swift test
.build/debug/MakeMyMacFastAgain
```

Screenshot automation mode: `.build/debug/MakeMyMacFastAgain --screenshots [output-dir]`

## Architecture

### App Lifecycle

```
main.swift
  -> NSApplication.shared
  -> AppDelegate (creates NSWindow with ContentView)
  -> AppState.startMonitoring()
  -> Timer-driven refresh loop
```

`main.swift` uses manual NSApplication setup (not SwiftUI App protocol) because the app needs direct control over window creation, menu bar, and screenshot automation mode.

`AppDelegate` creates two windows: the main app window and a separate Settings window (Cmd+,). It sets up the full menu bar (App, Edit, Window menus) programmatically.

### AppState (Central State Singleton)

`AppState` is the single source of truth for all system monitoring data. It:

- Owns all shared monitor instances (`CPUMonitor`, `MemoryMonitor`, `DiskMonitor`, `NetworkMonitor`, `ProcessService`)
- Runs a single `Timer` that calls `refresh()` at the configured interval (default 2s)
- Stores current stats, history arrays (30 samples), top processes, system info
- Computes a weighted health score (disk 30%, memory 25%, startup 20%, cache 15%, zombies 10%)
- Is injected into the SwiftUI view hierarchy via a custom `EnvironmentKey`:

```swift
@Environment(\.appState) private var appState
// Set at root: .environment(\.appState, appState)
```

### Feature Module Pattern

Each feature follows the pattern: `FeatureView` + `FeatureViewModel` (except Settings which is view-only).

**Features** (in `Sources/MakeMyMacFastAgain/Features/`):

| Feature | Description | Key Services Used |
|---------|-------------|-------------------|
| **Dashboard** | System overview with gauges, sparklines, health score | Reads from AppState (thin VM wrapper) |
| **Cache Cleaner** | Scan and clean user/system caches, Xcode, Homebrew, npm, logs | `FileScanner`, `PrivilegedExecutor` |
| **Browser Cleanup** | Clean cache/cookies for Safari, Chrome, Firefox, Edge, Arc, Brave | `FileScanner` |
| **Large File Finder** | Find and trash large files in home directory | `FileScanner` |
| **Process Manager** | List, filter, sort, kill processes with safety checks | `ProcessService` (via AppState) |
| **Startup Items** | View and toggle LaunchAgents/LaunchDaemons | `ShellExecutor`, `PrivilegedExecutor` |
| **Memory Optimizer** | Purge inactive memory via `/usr/sbin/purge` | `PrivilegedExecutor` |
| **DNS Flush** | Flush DNS cache, show resolvers, test latency | `PrivilegedExecutor`, `ShellExecutor` |
| **Settings** | Configure refresh intervals and safety confirmations | `AppSettings` (UserDefaults) |

ViewModels that need live system data bind to AppState via `vm.bind(to: appState)`, called in `onAppear`. The Dashboard VM is a thin pass-through; others (ProcessManager, MemoryOptimizer) use AppState's shared services but manage their own refresh timers.

### Navigation

`ContentView` uses `NavigationSplitView` with a sidebar of `NavigationItem` enum cases, grouped into `NavigationSection` (Overview, Cleanup, System). Keyboard shortcuts Cmd+1 through Cmd+8 for quick navigation.

### Service Layer

All services live in `Sources/MakeMyMacFastAgain/Services/`:

- **CPUMonitor** (`@MainActor`): Reads `host_processor_info` Mach API, computes delta-based CPU percentages across all cores
- **MemoryMonitor** (`@MainActor`): Reads `host_statistics64` for VM stats, uses `getpagesize()` for page size (not `vm_kernel_page_size` -- see Swift 6 gotchas)
- **DiskMonitor** (`@MainActor`): Uses URL resource values with fallback to FileManager attributes
- **NetworkMonitor** (`@MainActor`): Reads `getifaddrs` for physical interfaces (`en*`), computes rates from delta bytes / delta time
- **ProcessService** (`@MainActor`): Uses CSystemKit C target for process enumeration via `libproc.h`, enriches names with `NSWorkspace.shared.runningApplications`
- **FileScanner** (`actor`): Directory size calculation with TTL cache (30s), large file scanning with progress callbacks and cancellation support. Uses `nonisolated` helper for `FileManager.DirectoryEnumerator`
- **ShellExecutor** (`actor`): Runs shell commands via `Process` with configurable timeout, SIGTERM+SIGKILL on timeout, uses `nonisolated static` method with semaphore/GCD for non-blocking wait
- **PrivilegedExecutor** (`final class`): Enum-based command templates (`PrivilegedCommand`) with input validation (allowed path prefixes, path traversal rejection, label character validation). Executes via `NSAppleScript` `do shell script ... with administrator privileges`
- **PermissionChecker** (`struct, Sendable`): Checks Full Disk Access by testing readability of `~/Library/Safari/Bookmarks.plist`

### C Interop: CSystemKit

`Sources/CSystemKit/` is a C target wrapping `libproc.h` for process information:

- `csystemkit.h` defines `CSKProcessInfo` and `CSKProcessResourceUsage` structs
- `csystemkit.c` implements:
  - `csk_get_all_pids()` -- `proc_listallpids`
  - `csk_get_process_info()` -- `proc_pidpath` + `sysctl` for PID/PPID/UID/status, with version-string-to-app-name resolution from path
  - `csk_get_process_resource_usage()` -- `proc_pidinfo(PROC_PIDTASKINFO)` for resident size and CPU time

### Models

All in `Sources/MakeMyMacFastAgain/Models/`:

- **SystemStats.swift**: `CPUStats`, `MemoryStats`, `DiskStats`, `NetworkStats`, `AppProcessInfo`, `CacheCategory`, `BrowserProfile`, `StartupItem`, `LargeFile` -- all `: Sendable`
- **NavigationItem.swift**: `NavigationItem` and `NavigationSection` enums with section grouping, SF Symbol names, keyboard shortcut hints
- **AppSettings.swift**: `Codable` + `Sendable` settings struct persisted to UserDefaults with save/load/clear/corrupted-data recovery

### Shared UI Components

`Sources/MakeMyMacFastAgain/Shared/`:

- **GaugeCard**: Circular progress gauge with color thresholds (green < 60%, yellow < 80%, red >= 80%)
- **HealthScoreGauge**: Animated circular health score display with angular gradient
- **NetworkCard**: Download/upload rate display
- **StatusBar**: Generic bottom bar with loading indicator and trailing content
- **FeatureHeader**: Title + subtitle + action buttons header for feature views
- **FullDiskAccessBanner**: Dismissible banner prompting FDA, opens System Settings directly
- **ByteFormatter**: Static methods for formatting bytes, rates (B/s, KB/s, MB/s, GB/s), and percentages

## Testing

Uses Swift Testing framework (`@Test`, `@Suite`, `#expect`, `Issue.record`).

```bash
swift test       # or: make test
```

### Test Files

- **`Tests/MakeMyMacFastAgainTests.swift`**: Unit tests for `ByteFormatter`, `CPUMonitor`, `MemoryMonitor`, `DiskMonitor`, `NetworkMonitor`, `NavigationItem`, `ProcessService`
- **`Tests/SecurityTests.swift`**: Security-focused tests for `PrivilegedExecutor` (path validation, injection prevention, command building), `ProcessManagerViewModel` (protected PID safety), `AppSettings` (defaults, roundtrip, corrupted data), `ShellExecutor` (output, exit codes, timeout, stderr, executable-not-found)

### Test Configuration Note

Swift 6.3+ bundles the Swift Testing framework directly with the toolchain, so the test target uses the default configuration without any `unsafeFlags`. Earlier versions of this project required manual framework search paths to the Command Line Tools copy of `Testing.framework`; those flags were removed because with Swift 6.3 they caused a protocol mismatch between the compiler-generated macros (expecting `fileID:`) and the older bundled runtime (`__uncheckedFileID:`).

If you downgrade to a toolchain older than Swift 6.2, you may need to reintroduce `-F` search paths pointing to a matching `Testing.framework` copy.

## Swift 6 Strict Concurrency Gotchas

These are lessons learned that apply to future development on this codebase:

### MainActor Isolation

- All `@Observable` ViewModels must be annotated `@MainActor`
- Monitor/service classes that are only used from MainActor VMs should also be `@MainActor` (CPUMonitor, MemoryMonitor, DiskMonitor, NetworkMonitor, ProcessService)
- `NSAppleScript` must run on MainActor -- hence `PrivilegedExecutor.run()` is `@MainActor`
- Timer closure calling `@MainActor` methods needs `MainActor.assumeIsolated { }` wrapper:
  ```swift
  timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refresh() }
  }
  ```

### Global Mutable State

- `vm_kernel_page_size` is global mutable state in Swift 6 -- use `getpagesize()` instead
- `CaseIterable` extension `allCases` must be `let` not `var`

### Actor / Sendable Patterns

- All model structs must conform to `: Sendable`
- `FileScanner` and `ShellExecutor` are `actor` types for thread safety
- `FileManager.DirectoryEnumerator.makeIterator()` is unavailable in async contexts -- use `nonisolated` helper methods (see `FileScanner._calculateDirectorySize`)
- `ShellExecutor.awaitProcess` is `nonisolated static` so blocking pipe reads and process waits run on GCD threads, not the actor's serial executor

### SPM Specifics

- CSystemKit uses `.target()` not `.systemLibrary()` for C interop with libproc.h
- Do not use `-parse-as-library` with top-level code in `main.swift`
- The Testing framework requires explicit framework search paths pointing to Command Line Tools (see test configuration above)

### Naming Collisions

- `ProcessInfo` collides with `Foundation.ProcessInfo` -- our type is named `AppProcessInfo`
- When accessing Foundation's ProcessInfo, use `Foundation.ProcessInfo.processInfo` explicitly

## File Structure

```
.
├── CLAUDE.md                          # This file
├── Makefile                           # Build/run/test/bundle commands
├── Package.swift                      # SPM manifest (macOS 14+, Swift 6.0)
├── Resources/
│   └── Info.plist                     # App bundle metadata
├── Sources/
│   ├── CSystemKit/                    # C target for libproc.h interop
│   │   ├── include/
│   │   │   └── csystemkit.h           # CSKProcessInfo, CSKProcessResourceUsage
│   │   └── csystemkit.c               # proc_pidpath, proc_pidinfo, sysctl
│   └── MakeMyMacFastAgain/
│       ├── App/
│       │   ├── main.swift             # Entry point, NSApplication setup
│       │   ├── AppDelegate.swift      # Window creation, menu bar, Settings window
│       │   ├── AppState.swift         # Central state + monitors + timer + environment key
│       │   ├── ContentView.swift      # NavigationSplitView + sidebar + feature routing
│       │   └── ScreenshotMode.swift   # Automated screenshot capture for all features
│       ├── Features/
│       │   ├── Dashboard/             # DashboardView + DashboardViewModel
│       │   ├── CacheCleaner/          # CacheCleanerView + CacheCleanerViewModel
│       │   ├── BrowserCleanup/        # BrowserCleanupView + BrowserCleanupViewModel
│       │   ├── LargeFileFinder/       # LargeFileFinderView + LargeFileFinderViewModel
│       │   ├── ProcessManager/        # ProcessManagerView + ProcessManagerViewModel
│       │   ├── StartupItems/          # StartupItemsView + StartupItemsViewModel
│       │   ├── MemoryOptimizer/       # MemoryOptimizerView + MemoryOptimizerViewModel
│       │   ├── DNSFlush/              # DNSFlushView + DNSFlushViewModel
│       │   └── Settings/              # SettingsView (no ViewModel)
│       ├── Models/
│       │   ├── SystemStats.swift      # All data structs (CPUStats, MemoryStats, etc.)
│       │   ├── NavigationItem.swift   # Navigation enum with sections and SF Symbols
│       │   └── AppSettings.swift      # UserDefaults-backed settings with Codable
│       ├── Services/
│       │   ├── CPUMonitor.swift       # Mach API host_processor_info
│       │   ├── MemoryMonitor.swift    # Mach API host_statistics64
│       │   ├── DiskMonitor.swift      # URL resource values / FileManager
│       │   ├── NetworkMonitor.swift   # getifaddrs for en* interfaces
│       │   ├── ProcessService.swift   # CSystemKit + NSWorkspace process listing
│       │   ├── FileScanner.swift      # Actor: directory scanning with TTL cache
│       │   ├── ShellExecutor.swift    # Actor: Process execution with timeout
│       │   ├── PrivilegedExecutor.swift # NSAppleScript admin commands
│       │   └── PermissionChecker.swift  # Full Disk Access detection
│       └── Shared/
│           ├── ByteFormatter.swift    # Byte/rate/percentage formatting
│           ├── GaugeCard.swift        # Circular gauge component
│           ├── HealthScoreGauge.swift  # Animated health score ring
│           ├── NetworkCard.swift      # Network rate display card
│           ├── StatusBar.swift        # Generic bottom status bar
│           ├── FeatureHeader.swift    # Feature title + actions header
│           └── FullDiskAccessBanner.swift  # FDA onboarding banner
├── Tests/
│   ├── MakeMyMacFastAgainTests.swift  # Unit tests for formatters, monitors, navigation
│   └── SecurityTests.swift            # Security tests for privileged execution, process safety
├── screenshots/                       # Auto-generated feature screenshots
├── TODOS.md                           # Project roadmap and TODO items
└── USER_STORIES.md                    # Feature user stories
```

## Security Considerations

- **PrivilegedExecutor** only accepts predefined command templates via the `PrivilegedCommand` enum -- no arbitrary shell execution
- Cache path validation: only `/Library/Caches` and `~/Library/Caches` prefixes allowed, path traversal (`..`) rejected
- Launchctl label validation: only alphanumerics, dots, hyphens, underscores allowed
- Process kill safety: own PID, PID 0, PID 1, and `kernel_task` are protected; PID reuse race condition guarded by re-reading process name before kill
- Single-quote shell escaping for cache paths passed to `rm -rf`
