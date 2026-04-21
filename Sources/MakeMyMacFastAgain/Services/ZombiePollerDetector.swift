import Foundation
import os

/// Detects runaway shell loops — orphaned `sh -c` / `zsh -c` / `bash -c`
/// processes that spawn short-lived children at high frequency (e.g. a forgotten
/// `while true; do kubectl …; sleep 2; done`).
///
/// Activity Monitor shows only the ephemeral children and never the parent
/// shell, so these loops can run for hours driving up load average while
/// appearing invisible. This detector records per-tick process snapshots and
/// ranks parents by child-spawn rate crossed with a shell-loop command match.
@MainActor
final class ZombiePollerDetector {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "zombie-poller")

    /// How long between process-list snapshots the detector expects. Used to
    /// convert sample counts into wall-clock windows when computing spawn rate.
    /// Must stay in sync with AppState's refresh timer.
    nonisolated static let sampleIntervalSeconds: Double = 2.0

    /// Maximum number of ticks kept. 60 samples at 2s = 2-minute window.
    private let maxSamples = 60

    /// Minimum distinct children observed in the window to qualify as a poller.
    private let childSpawnThreshold = 3

    /// Minimum process age before we consider it suspicious (avoids flagging
    /// a just-started legitimate pipeline).
    private let minimumAgeSeconds: Double = 60

    /// Sliding history of child-PID-sets keyed by parent PID. Each entry is the
    /// set of child PIDs observed under that parent on a single tick.
    private var parentChildHistory: [pid_t: [Set<pid_t>]] = [:]

    /// PIDs explicitly dismissed by the user for the current session.
    var ignoredPIDs: Set<pid_t> = []

    /// Own PID — never flag ourselves.
    private let ownPID: pid_t = getpid()

    /// Processes that must never be reported even if they match.
    private let protectedNames: Set<String> = ["launchd", "kernel_task", "mds", "mds_stores", "Spotlight"]

    /// Match common shell loop idioms: `while`/`until` loops and polling
    /// constructs that sleep between iterations. Anchored word-boundaries
    /// keep substrings like `whilefoo` from matching.
    ///
    /// Exposed `internal` so tests can exercise it directly.
    nonisolated static let loopRegex: NSRegularExpression = {
        // Real shell-loop command lines always have the loop keyword BEFORE
        // the sleep call (`while … sleep …`). A reversed ordering only shows
        // up in contrived or unrelated commands, so we only match the forward
        // direction to keep false-positive surface minimal.
        let pattern = #"(?i)\b(while|until|for)\b.*\bsleep\b"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    /// Shell interpreter basenames we consider candidates for hosting a loop.
    nonisolated static let shellNames: Set<String> = ["sh", "bash", "zsh", "dash", "ksh", "fish"]

    // MARK: - Ingest

    /// Feed the detector the latest process snapshot. Called once per refresh
    /// tick by AppState. Updates the sliding window and returns the ranked
    /// list of currently-detected zombie pollers.
    @discardableResult
    func ingest(processes: [AppProcessInfo], now: Date = Date()) -> [ZombiePoller] {
        // Build pid -> ppid map and the per-parent child set for this tick.
        var childrenByParent: [pid_t: Set<pid_t>] = [:]
        var processesByPID: [pid_t: AppProcessInfo] = [:]
        for proc in processes {
            processesByPID[proc.pid] = proc
            if proc.ppid > 0 {
                childrenByParent[proc.ppid, default: []].insert(proc.pid)
            }
        }

        // Append the tick's observation, but only for processes that could
        // actually be zombie pollers. Non-shell PIDs never pass the
        // classification gate anyway, so tracking them wastes memory on a
        // typical Mac running 400+ processes.
        for (pid, proc) in processesByPID where Self.isCandidateShell(proc) {
            let snapshot = childrenByParent[pid] ?? []
            var history = parentChildHistory[pid] ?? []
            history.append(snapshot)
            if history.count > maxSamples {
                history.removeFirst(history.count - maxSamples)
            }
            parentChildHistory[pid] = history
        }

        // Forget parents that have exited (conserves memory and avoids stale matches).
        for pid in parentChildHistory.keys where processesByPID[pid] == nil {
            parentChildHistory.removeValue(forKey: pid)
        }

        // Classify.
        let nowSeconds = now.timeIntervalSince1970
        var results: [ZombiePoller] = []

        for (pid, proc) in processesByPID {
            if pid == ownPID { continue }
            if ignoredPIDs.contains(pid) { continue }
            if protectedNames.contains(proc.name) { continue }

            guard Self.isCandidateShell(proc) else { continue }
            guard Self.commandLineMatchesLoop(proc.commandLine) else { continue }

            // Age gate: fresh pipelines get a grace period.
            if proc.startTime > 0 {
                let age = nowSeconds - Double(proc.startTime)
                if age < minimumAgeSeconds { continue }
            }

            let history = parentChildHistory[pid] ?? []
            let distinctChildren = Self.distinctChildCount(in: history)
            if distinctChildren < childSpawnThreshold { continue }

            let uptime = proc.startTime > 0 ? max(0, nowSeconds - Double(proc.startTime)) : 0

            results.append(
                ZombiePoller(
                    id: pid,
                    pid: pid,
                    ppid: proc.ppid,
                    shell: proc.name,
                    command: Self.prettyCommand(proc.commandLine),
                    startTime: proc.startTime,
                    uptimeSeconds: uptime,
                    cpuTimeNanos: proc.cpuUsage,
                    recentChildSpawns: distinctChildren,
                    recentChildSamples: history.count
                )
            )
        }

        // Rank: worst offenders first — by spawn rate, then uptime.
        results.sort { lhs, rhs in
            if lhs.spawnsPerMinute != rhs.spawnsPerMinute {
                return lhs.spawnsPerMinute > rhs.spawnsPerMinute
            }
            return lhs.uptimeSeconds > rhs.uptimeSeconds
        }

        if !results.isEmpty {
            logger.info("Detected \(results.count, privacy: .public) zombie poller(s)")
        }

        return results
    }

    /// Clear all history. Called on monitor restart.
    func reset() {
        parentChildHistory.removeAll()
    }

    // MARK: - Classification helpers (pure, testable)

    /// True if the process looks like a shell candidate: name is exactly one
    /// of the known shells AND its command line contains the `-c` flag (which
    /// is how `while … sleep … done` style loops are invoked from a launched
    /// shell). The exact-match requirement avoids false positives from
    /// shell-adjacent tools like `zsh-syntax-highlighting` or `bash-preexec`.
    nonisolated static func isCandidateShell(_ proc: AppProcessInfo) -> Bool {
        guard shellNames.contains(proc.name.lowercased()) else {
            return false
        }
        return proc.commandLine.contains(" -c ") || proc.commandLine.hasSuffix(" -c")
    }

    /// True if the command line matches a poll/loop pattern.
    nonisolated static func commandLineMatchesLoop(_ command: String) -> Bool {
        guard !command.isEmpty else { return false }
        let range = NSRange(command.startIndex..<command.endIndex, in: command)
        return loopRegex.firstMatch(in: command, options: [], range: range) != nil
    }

    /// Count distinct child PIDs seen across the sliding window. Parents that
    /// keep the same long-lived children contribute 1 (not suspicious). Parents
    /// whose children rotate rapidly contribute N (the signature we want).
    nonisolated static func distinctChildCount(in history: [Set<pid_t>]) -> Int {
        var seen: Set<pid_t> = []
        for snapshot in history {
            seen.formUnion(snapshot)
        }
        return seen.count
    }

    /// Reduce runs of whitespace for readable display. Keeps the original
    /// argument ordering so the user can still copy-paste and run the command.
    nonisolated static func prettyCommand(_ command: String) -> String {
        command
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
