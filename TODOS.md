# Make My Mac Fast Again — TODOS

## Priority Legend
- **P1** = Must do before v1.0 (security, reliability, foundational)
- **P2** = Should do for v1.0 (features, polish, distribution)
- **P3** = Nice to have (documentation, minor improvements)

## Effort Legend
- **XS** = < 1 hour | **S** = 1-3 hours | **M** = 3-8 hours | **L** = 1-3 days | **XL** = 3+ days

---

## P1 — Critical / Foundational

### TODO 1: Refactor to AppState Singleton
- **What:** Extract CPU/Memory/Disk/Network monitors + ProcessService into shared `@Observable AppState` injected via `.environment()`
- **Why:** Current ViewModels are recreated on navigation, duplicating monitors and losing state. Cross-feature awareness (Health Score, menubar, notifications) is impossible without shared state.
- **Effort:** L
- **Depends on:** Nothing (foundational — do first)
- **Blocks:** TODO 6, TODO 7, TODO 8

### TODO 2: Harden PrivilegedExecutor with Command Templates
- **What:** Replace string prefix allowlist with enum-based command types (`.flushDNS`, `.purgeMemory`, `.removeCache(path:)`, `.launchctl(action:domain:label:)`). Each template validates parameters against known-safe values.
- **Why:** Current `rm -rf '` prefix allows admin deletion of any path starting with a quote — HIGH severity security gap.
- **Effort:** M
- **Depends on:** Nothing
- **Blocks:** TODO 4

### TODO 3: Add Timeout to ShellExecutor
- **What:** Configurable timeout (default 10s) with `process.terminate()` fallback. Return a specific `TimeoutError` so callers show appropriate UI.
- **Why:** `process.waitUntilExit()` blocks forever if a command hangs (ping, launchctl, scutil). CRITICAL reliability fix.
- **Effort:** S
- **Depends on:** Nothing

### TODO 4: Protocol-Based Service Injection + Security Tests
- **What:** Define protocols for all services (MonitorProtocol, ExecutorProtocol, etc.). Inject via init for testability. Write focused tests for: PrivilegedExecutor command templates, process kill guards, cleanup error handling, AppSettings corruption recovery.
- **Why:** ~95% of code is untested. Security-critical paths (admin exec, process kill) have zero tests.
- **Effort:** L
- **Depends on:** TODO 2 (PrivilegedExecutor templates)

### TODO 12: Process Manager Safety Guards
- **What:** Filter own app PID from kill list. Before `kill()`, re-read process info and verify name matches. Guard against killing critical system processes (PID 0, 1, kernel_task).
- **Why:** Killing own app = crash. PID reuse = killing wrong process. Both are embarrassing for a system utility.
- **Effort:** S
- **Depends on:** Nothing

---

## P2 — Features / Polish / Distribution

### TODO 5: Add os.Logger Throughout All Services
- **What:** Subsystem: `io.tunk.make-my-mac-fast-again`. Categories: monitoring, cleanup, process, privileged, network, startup, settings. Debug for routine, error for failures, info for user actions.
- **Why:** Zero logging = zero diagnosability when users report issues.
- **Effort:** M
- **Depends on:** Nothing

### TODO 6: Health Score on Dashboard
- **What:** Composite score (0-100) combining: disk usage (weight 0.3), memory pressure (0.25), startup item count/impact (0.2), cache size (0.15), zombie processes (0.1). Large circular gauge with color gradient.
- **Why:** Key differentiator. Transforms app from "collection of tools" to "trusted advisor."
- **Effort:** M
- **Depends on:** TODO 1 (AppState)

### TODO 7: Menubar Mode with NSStatusItem
- **What:** Health score color-coded icon. Dropdown: quick stats, "Optimize Now", "Open App", "Quit". Don't terminate on window close. Toggle activation policy on window show/hide.
- **Why:** Persistent system utilities live in the menubar. This is the 10x UX upgrade.
- **Effort:** M
- **Depends on:** TODO 1 (AppState), TODO 6 (Health Score)

### TODO 8: macOS Native Notifications
- **What:** `UNUserNotificationCenter` for: disk >90%, memory critical, zombie processes. Rate-limited (1/hour/category). Opt-in in Settings.
- **Why:** Proactive advisor > reactive tool. Users get warned before things go wrong.
- **Effort:** S
- **Depends on:** TODO 1 (AppState), TODO 7 (menubar for always-on)

### TODO 9: Code Signing + Notarization + Distribution
- **What:** Makefile targets for codesign (Developer ID), notarytool, create-dmg, Homebrew cask formula. Sparkle framework for auto-updates with appcast.xml.
- **Why:** Unsigned apps trigger Gatekeeper warnings. No distribution = no users.
- **Effort:** L
- **Depends on:** Apple Developer account ($99/yr)

### TODO 11: FileScanner Size Caching with TTL
- **What:** In-memory cache: directory path → (size, timestamp). 30s TTL. Invalidate on clean. Add `Task.isCancelled` to `calculateDirectorySize`.
- **Why:** Up to 56 redundant directory enumerations during a clean cycle. Biggest perf bottleneck.
- **Effort:** S
- **Depends on:** Nothing

---

## P3 — Documentation / Minor

### TODO 10: Add CLAUDE.md Architecture Documentation
- **What:** Project overview, directory structure, architecture diagram (ASCII), coding conventions (Swift 6 concurrency, @MainActor patterns), development setup, feature map.
- **Why:** Reduces onboarding friction for new contributors.
- **Effort:** S
- **Depends on:** TODO 1 (AppState — document the new architecture)

---

## Delight Opportunities (< 30 min each)

### Delight 1: "Before You Clean" Dry-Run Preview
- Show modal with exact file list before any cleanup. Grouped by type, with total size.
- **Why:** Users feel safe because they see exactly what's happening.
- **Effort:** 20 min

### Delight 2: "Last Cleaned" Timestamp on Dashboard
- Subtle line: "Last cleanup: 3 days ago • Freed 2.4 GB". Persisted in UserDefaults.
- **Why:** App feels like it's keeping track for you.
- **Effort:** 15 min

### Delight 3: Animated Gauge Transitions
- `.animation(.smooth, value: value)` on GaugeCard. Gauges smoothly animate on refresh.
- **Why:** Feels alive and polished vs. snapping to new values.
- **Effort:** 10 min

### Delight 4: Custom App Icon
- Designed icon (speedometer or rocket). Shows in menubar, dock, About dialog.
- **Why:** Makes the app feel intentional, not a side project.
- **Effort:** 30 min

### Delight 5: Keyboard Shortcut Hints in Sidebar
- Subtle ⌘1, ⌘2 hints next to sidebar items. Disappear after first use.
- **Why:** Power users discover shortcuts naturally.
- **Effort:** 15 min

---

## Straightforward Fixes (no decision needed)

- [ ] CacheCleanerVM.swift:189 — Replace `try?` with counted failures, show "Cleaned X of Y (Z failed)"
- [ ] StartupItemsViewModel.swift:163 — Move `import AppKit` to top of file
- [ ] MemoryOptimizerViewModel.swift:41-47 — Return `SwiftUI.Color` instead of String for pressure level
- [ ] ShellExecutor — Use `Process.arguments` array instead of string interpolation to prevent injection
- [ ] DashboardView — Add "Loading..." state for first-tick gauges showing 0%
