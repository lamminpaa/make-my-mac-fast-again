import Foundation
import Darwin
import os

@MainActor
@Observable
final class ZombiePollersViewModel {
    private let logger = Logger(
        subsystem: "io.tunk.make-my-mac-fast-again",
        category: "zombie-pollers-vm"
    )

    var statusMessage: String = ""

    private weak var appState: AppState?
    private let ownPID = getpid()

    /// Reads directly from AppState so SwiftUI auto-updates as the detector
    /// re-runs on each monitoring tick.
    var pollers: [ZombiePoller] {
        appState?.zombiePollers ?? []
    }

    func bind(to appState: AppState) {
        self.appState = appState
        refreshStatus()
    }

    /// Recompute the human-readable status string.
    func refreshStatus() {
        let count = pollers.count
        statusMessage = count == 0
            ? "No runaway loops detected"
            : "\(count) runaway loop\(count == 1 ? "" : "s") detected"
    }

    func kill(_ poller: ZombiePoller) async {
        if poller.pid == ownPID {
            statusMessage = "Cannot kill own process"
            return
        }
        if poller.pid <= 1 {
            statusMessage = "Refusing to kill protected PID \(poller.pid)"
            return
        }

        // Verify identity before killing — PID could have been reused between
        // the last tick and this action. Compare BOTH name and startTime: a
        // fresh zsh at the same PID matches on name alone, so startTime is
        // the real guarantee this is the same process we detected.
        guard let current = appState?.processService.getProcessInfo(pid: poller.pid) else {
            statusMessage = "PID \(poller.pid) no longer exists"
            return
        }
        if current.name != poller.shell || current.startTime != poller.startTime {
            statusMessage = "PID \(poller.pid) identity changed — aborting"
            return
        }

        let result = Darwin.kill(poller.pid, SIGTERM)
        if result == 0 {
            logger.info("Killed zombie poller PID \(poller.pid, privacy: .public)")
            statusMessage = "Sent SIGTERM to \(poller.shell) (PID \(poller.pid))"
        } else {
            let err = String(cString: strerror(errno))
            logger.warning("kill(\(poller.pid)) failed: \(err, privacy: .public)")
            statusMessage = "Failed to kill PID \(poller.pid): \(err)"
        }
    }

    func ignore(_ poller: ZombiePoller) {
        appState?.zombiePollerDetector.ignoredPIDs.insert(poller.pid)
        statusMessage = "Ignoring PID \(poller.pid) for this session"
    }
}
