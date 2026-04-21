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

## P2 — Real-World Insights (April 2026 dogfooding session)

These items come from an actual debugging session where a user's Mac had load average 152, disk 97% full, and the root causes were invisible to existing macOS tools (Activity Monitor, About This Mac). They would have been caught by this app — *if* the app had these features. Ordered by effort ascending so quick wins ship first.

### ~~TODO 13: Add CoreSimulator Cleanup Category~~ DONE
- **What:** New "iOS Simulators (unavailable)" category in CacheCleaner running `xcrun simctl delete unavailable` via ShellExecutor. Extended `CacheCategory` with an optional `cleanupCommand` strategy so future shell-based cleanups slot in without special-casing.
- **Commit:** `feat(cache): add iOS Simulator cleanup via xcrun simctl delete unavailable`

### ~~TODO 14: Load Average on Dashboard~~ DONE
- **What:** `LoadStats` struct + `CPUMonitor.readLoad()` via `getloadavg(3)`, surfaced through AppState and a new `LoadCard` rendered on the Dashboard between sparklines and network detail. Color thresholds relative to active CPU count (green < 0.7×cores, yellow < 1.5×cores, red ≥ 1.5×cores).
- **Commit:** `feat(dashboard): surface Unix load averages via getloadavg`

### TODO 15: Docker.raw Sparse File Recognition
- **What:** New CacheCleaner category "Docker disk image". Detects `~/Library/Containers/com.docker.docker/Data/vms/*/data/Docker.raw`, reports both **virtual size** (`ls -l`) and **allocated size** (`du`) side-by-side. Offers two actions:
  1. *Reclaim space* — guides user to Docker Desktop → Settings → Resources → "Clean / Purge data"
  2. *Delete disk image* — confirms Docker daemon is stopped, then removes file (daemon recreates on next start). Large warning: destroys all containers, images, volumes.
- **Why:** Single biggest disk hog in real session (417 GB actual / 924 GB virtual). Completely invisible to `du ~/Library/Caches`-style tools because it lives in Containers. No existing app feature catches this.
- **Effort:** S
- **How:** Extend FileScanner with a "known large artifacts" registry (path pattern + display name + cleanup strategy). For sparse files, use `stat -f '%z %b'` to get both allocated bytes and logical size.

### TODO 16: APFS Purgeable Space + Local Snapshots Panel
- **What:** Dashboard section showing three disk numbers instead of one: **Real free** | **Purgeable** | **Snapshots**. Action button "Delete local snapshots" calls `tmutil deletelocalsnapshots /` (requires admin). List individual snapshots via `tmutil listlocalsnapshots /`.
- **Why:** In the dogfood session, cleaning 50 GB barely moved `df avail` because APFS held the space for local Time Machine snapshots. Users see "cleanup did nothing" and distrust the app. Separating apparent free from real free prevents this.
- **Effort:** S
- **How:** Parse `diskutil info /System/Volumes/Data` output for "Container Free Space" vs `df` avail. Add `PrivilegedCommand.deleteLocalSnapshots` enum case. Poll snapshot list via `tmutil listlocalsnapshots`.

### TODO 17: Rebuild Artifacts Scanner (new feature view)
- **What:** New sidebar item under Cleanup: "Rebuild Artifacts". Recursively scans `~/Documents` (and user-chosen roots) for directories matching a known allow-list of regenerable build output folders. Groups results by containing project, shows last-modified age. Move-to-Trash per-directory or bulk.
- **Why:** Large File Finder finds big *files*; it doesn't find **thousands of small files** in regenerable directories. In the dogfood session, `~/Documents` alone was 716 GB — most of it was `node_modules`, `.next`, `DerivedData-per-project`, etc. Users typically free 50–200 GB here with zero risk (these directories rebuild on next `npm install` / `next build`).
- **Effort:** M
- **How:** Known-names allow-list: `node_modules`, `.next`, `.nuxt`, `.turbo`, `.parcel-cache`, `.svelte-kit`, `dist`, `build`, `out`, `target` (Rust/Java — need content heuristic to distinguish), `__pycache__`, `.venv`, `venv`, `vendor` (Composer/Go — heuristic), `bower_components`, `.gradle`, `DerivedData`. Extend `FileScanner` with `scanRebuildArtifacts(roots:)` actor method using the existing `nonisolated` directory-enumerator pattern. Respect `.gitignore`? No — these dirs are the point. Use `NSMetadataQuery` or iterate manually; iteration is simpler and works without Spotlight indexing (which was broken in the session).

### TODO 18: Parent-Process Chain in Process Manager
- **What:** ProcessManager shows a "Launched by" column (or expandable detail row) with full parent chain up to PID 1. Sort/filter option "Group by parent tree" collapses children under parents. Hover tooltip shows the full command line of each ancestor.
- **Why:** In the dogfood session, `Python (66% CPU)`, `gcloud`, `kubectl`, `gke-gcloud-auth-plugin` appeared as separate rows with unrelated names. The user saw "why is Python eating CPU?" — but the answer was two levels up the tree (an orphaned `zsh -c` running `kubectl` in a loop). Parent chain turns mystery into obvious cause.
- **Effort:** M
- **How:** `ProcessService` already uses `sysctl KERN_PROC_PID` which returns PPID in `kinfo_proc`. Build parent map once per refresh (pid → ppid), resolve chains lazily. Render as disclosure group in `ProcessManagerView`'s List.

### ~~TODO 19: Runaway Loop / Zombie Poller Detection (signature feature)~~ DONE
- **What:** New "Zombie Pollers" sidebar item + compact Dashboard card. `ZombiePollerDetector` keeps a 60-sample (~2 min) sliding window of child PIDs per candidate shell parent and flags `sh`/`bash`/`zsh -c` processes whose command matches `(while|until|for) .* sleep` once ≥3 distinct children have rotated through the window. Age gate: 60 s minimum. Kill action verifies both `name` *and* `startTime` to defeat same-binary PID reuse. Per-session ignore list.
- **Commit:** `feat(detector): detect orphaned shell-loop zombie pollers`

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
