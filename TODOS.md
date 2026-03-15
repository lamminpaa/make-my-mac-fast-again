# Make My Mac Fast Again — TODOS

## Priority Legend
- **P1** = Must do before v1.0 (security, reliability, foundational)
- **P2** = Should do for v1.0 (features, polish, distribution)
- **P3** = Nice to have (documentation, minor improvements)

## Effort Legend
- **XS** = < 1 hour | **S** = 1-3 hours | **M** = 3-8 hours | **L** = 1-3 days | **XL** = 3+ days

---

## P1 — Critical / Foundational

### ~~TODO 1: Refactor to AppState Singleton~~ DONE
- **What:** Extract CPU/Memory/Disk/Network monitors + ProcessService into shared `@Observable AppState` injected via `.environment()`
- **Commit:** `feat(arch): extract AppState singleton and add FileScanner caching`

### ~~TODO 2: Harden PrivilegedExecutor with Command Templates~~ DONE
- **What:** Enum-based command types (`.flushDNS`, `.purgeMemory`, `.removeCache(path:)`, `.launchctl(action:domain:label:)`)
- **Commit:** `feat(security): harden PrivilegedExecutor, ShellExecutor, and ProcessManager`

### ~~TODO 3: Add Timeout to ShellExecutor~~ DONE
- **What:** Configurable timeout with SIGTERM → SIGINT escalation via DispatchSemaphore
- **Commit:** `feat(security): harden PrivilegedExecutor, ShellExecutor, and ProcessManager`

### ~~TODO 4: Protocol-Based Service Injection + Security Tests~~ DONE
- **What:** 24 security tests across 4 suites (PrivilegedExecutor, ProcessManager, AppSettings, ShellExecutor)
- **Commit:** `feat(product): Health Score gauge, os.Logger, security tests, and delight items`

### ~~TODO 12: Process Manager Safety Guards~~ DONE
- **What:** Protected PIDs (0, 1, kernel_task, own PID), PID reuse verification before kill
- **Commit:** `feat(security): harden PrivilegedExecutor, ShellExecutor, and ProcessManager`

---

## P2 — Features / Polish / Distribution

### ~~TODO 5: Add os.Logger Throughout All Services~~ DONE
- **What:** Subsystem `io.tunk.make-my-mac-fast-again` with category per service
- **Commit:** `feat(product): Health Score gauge, os.Logger, security tests, and delight items`

### ~~TODO 6: Health Score on Dashboard~~ DONE
- **What:** Composite score (0-100) with animated circular gauge
- **Commit:** `feat(product): Health Score gauge, os.Logger, security tests, and delight items`

### ~~TODO 7: Menubar Mode with NSStatusItem~~ DONE
- **What:** Status bar icon with popover showing health score, CPU, memory, disk, network stats
- **Commit:** `feat(menubar): add NSStatusItem with system stats popover`

### ~~TODO 8: macOS Native Notifications~~ DONE
- **What:** UNUserNotificationCenter for memory >90%, disk >90%, cleanup complete. 5-min throttle.
- **Commit:** `feat(notifications): add macOS native notifications and CLAUDE.md architecture docs`

### TODO 9: Code Signing + Notarization + Distribution
- **What:** Makefile targets for codesign (Developer ID), notarytool, create-dmg, Homebrew cask formula. Sparkle framework for auto-updates with appcast.xml.
- **Why:** Unsigned apps trigger Gatekeeper warnings. No distribution = no users.
- **Effort:** L
- **Depends on:** Apple Developer account ($99/yr)
- **Status:** BLOCKED — requires Apple Developer Program enrollment

### ~~TODO 11: FileScanner Size Caching with TTL~~ DONE
- **What:** In-memory cache with 30s TTL, invalidation on clean, Task.isCancelled support
- **Commit:** `feat(arch): extract AppState singleton and add FileScanner caching`

---

## P3 — Documentation / Minor

### ~~TODO 10: Add CLAUDE.md Architecture Documentation~~ DONE
- **What:** 263-line architecture document with file structure, patterns, Swift 6 gotchas
- **Commit:** `feat(notifications): add macOS native notifications and CLAUDE.md architecture docs`

---

## Delight Opportunities

### ~~Delight 1: "Before You Clean" Dry-Run Preview~~ DONE
- CleanPreviewSheet modal showing exact file list before cleanup
- **Commit:** `feat(product): Health Score gauge, os.Logger, security tests, and delight items`

### ~~Delight 2: "Last Cleaned" Timestamp on Dashboard~~ DONE
- "Last cleanup: 3 days ago - Freed 2.4 GB" bar on Dashboard
- **Commit:** `feat(product): Health Score gauge, os.Logger, security tests, and delight items`

### ~~Delight 3: Animated Gauge Transitions~~ DONE
- `.animation(.smooth)` + `.contentTransition(.numericText())` on GaugeCard
- **Commit:** `feat(product): Health Score gauge, os.Logger, security tests, and delight items`

### ~~Delight 4: Custom App Icon~~ DONE
- Programmatically generated speedometer icon with blue-teal gradient
- **Commit:** `feat(icon): add custom app icon with speedometer design`

### ~~Delight 5: Keyboard Shortcut Hints in Sidebar~~ DONE
- Subtle Cmd+1..8 hints in sidebar items
- **Commit:** `feat(product): Health Score gauge, os.Logger, security tests, and delight items`

---

## Straightforward Fixes

- [x] CacheCleanerVM.swift:189 — Replace `try?` with counted failures, show "Cleaned X of Y (Z failed)"
- [x] StartupItemsViewModel.swift:163 — Move `import AppKit` to top of file
- [x] MemoryOptimizerViewModel.swift:41-47 — Return `SwiftUI.Color` instead of String for pressure level
- [x] ShellExecutor — Use `Process.arguments` array via `run(executablePath:arguments:)` to prevent injection
- [x] DashboardView — Add "Loading..." state for first-tick gauges showing 0%

---

## Security Fixes (from code review)

- [x] Remove double single-quote escaping in PrivilegedExecutor AppleScript context
- [x] Use `executablePath:arguments:` for launchctl user agent commands
- [x] Use `executablePath:arguments:` for DNS ping commands
- [x] Wrap test helpers in `#if DEBUG`
- [x] Lazy-init UNUserNotificationCenter to prevent crash without bundle
