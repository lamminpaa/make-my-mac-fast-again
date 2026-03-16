# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-16

### Added
- Dashboard with real-time CPU, memory, disk, and network monitoring
- Weighted health score gauge (disk 30%, memory 25%, startup 20%, cache 15%, zombies 10%)
- Cache Cleaner for user/system caches, Xcode, Homebrew, npm, and logs
- Browser Cleanup for Safari, Chrome, Firefox, Edge, Arc, and Brave
- Large File Finder with home directory scanning
- Process Manager with safety-guarded kill (protected PIDs: 0, 1, kernel_task, self)
- Startup Items viewer with LaunchAgent/LaunchDaemon toggle
- Memory Optimizer via `/usr/sbin/purge`
- DNS Flush with resolver info and latency testing (Quad9 preset)
- Settings window (Cmd+,) with configurable refresh intervals and safety confirmations
- Menu bar status item with system stats popover
- Full Disk Access onboarding banner
- macOS native notifications for cleanup completion
- Custom app icon
- Screenshot automation mode (`--screenshots`)
- CSystemKit C target for libproc.h process enumeration
- PrivilegedExecutor with input-validated AppleScript admin commands
- Structured os.Logger across all ViewModels
- 48 unit and security tests

### Security
- PrivilegedExecutor uses enum-based command templates (no arbitrary shell execution)
- Cache path validation: only `/Library/Caches` and `~/Library/Caches` prefixes
- Path traversal rejection for cache cleanup paths
- Launchctl label character validation
- Protected PID list with PID-reuse race condition guard
- Single-quote shell escaping for rm paths
