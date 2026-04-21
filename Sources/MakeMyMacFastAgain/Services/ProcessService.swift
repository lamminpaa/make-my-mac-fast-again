import Foundation
import AppKit
import CSystemKit
import os

@MainActor
final class ProcessService {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "process")

    func listProcesses() -> [AppProcessInfo] {
        // Build PID -> localizedName lookup from running GUI applications
        let runningAppNames = buildRunningAppNameLookup()

        var pids = [pid_t](repeating: 0, count: 2048)
        let count = csk_get_all_pids(&pids, Int32(pids.count))

        guard count > 0 else {
            logger.error("csk_get_all_pids returned \(count)")
            return []
        }

        var processes: [AppProcessInfo] = []

        for i in 0..<Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var info = CSKProcessInfo()
            var usage = CSKProcessResourceUsage()

            guard csk_get_process_info(pid, &info) == 0 else { continue }

            var name = withUnsafePointer(to: &info.name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 256) { charPtr in
                    String(cString: charPtr)
                }
            }

            guard !name.isEmpty else { continue }

            // If the C-level name still looks like a version number or is very short,
            // try the NSRunningApplication lookup for a better display name
            if looksLikeVersionString(name) || name.count <= 2 {
                if let betterName = runningAppNames[pid] {
                    name = betterName
                }
            }

            var memoryBytes: UInt64 = 0
            var cpuTime: Double = 0

            if csk_get_process_resource_usage(pid, &usage) == 0 {
                memoryBytes = usage.resident_size
                cpuTime = usage.cpu_usage
            }

            let user = resolveUsername(uid: info.uid)

            processes.append(AppProcessInfo(
                id: pid,
                pid: pid,
                ppid: info.ppid,
                name: name,
                user: user,
                cpuUsage: cpuTime,
                memoryBytes: memoryBytes,
                status: processStatus(info.status),
                startTime: info.start_time_seconds,
                commandLine: readCommandLine(pid: pid)
            ))
        }

        logger.debug("listProcesses: found \(processes.count) processes")
        return processes
    }

    /// Look up a single process by PID, returning nil if it no longer exists.
    func getProcessInfo(pid: pid_t) -> AppProcessInfo? {
        var info = CSKProcessInfo()
        var usage = CSKProcessResourceUsage()

        guard csk_get_process_info(pid, &info) == 0 else { return nil }

        let name = withUnsafePointer(to: &info.name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 256) { charPtr in
                String(cString: charPtr)
            }
        }

        guard !name.isEmpty else { return nil }

        var memoryBytes: UInt64 = 0
        var cpuTime: Double = 0

        if csk_get_process_resource_usage(pid, &usage) == 0 {
            memoryBytes = usage.resident_size
            cpuTime = usage.cpu_usage
        }

        let user = resolveUsername(uid: info.uid)

        return AppProcessInfo(
            id: pid,
            pid: pid,
            ppid: info.ppid,
            name: name,
            user: user,
            cpuUsage: cpuTime,
            memoryBytes: memoryBytes,
            status: processStatus(info.status),
            startTime: info.start_time_seconds,
            commandLine: readCommandLine(pid: pid)
        )
    }

    /// Read a process's full command line via KERN_PROCARGS2 and join with spaces.
    /// Returns an empty string when argv is unreadable (common for root-owned processes
    /// when running without elevated privileges).
    private func readCommandLine(pid: pid_t) -> String {
        let bufferSize = 4096
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            csk_get_process_args(pid, ptr.baseAddress, Int32(bufferSize))
        }
        guard result > 0 else { return "" }
        let raw = buffer.withUnsafeBufferPointer { ptr -> String in
            guard let base = ptr.baseAddress else { return "" }
            return String(cString: base)
        }
        // csystemkit.c joins argv entries with 0x1F (unit separator).
        return raw.replacingOccurrences(of: "\u{1F}", with: " ")
    }

    /// Build a PID-to-localized-name mapping from NSWorkspace running applications
    private func buildRunningAppNameLookup() -> [pid_t: String] {
        var lookup: [pid_t: String] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if let localizedName = app.localizedName, !localizedName.isEmpty {
                lookup[app.processIdentifier] = localizedName
            }
        }
        return lookup
    }

    /// Returns true if the string looks like a version number (digits and dots only, e.g. "2.1.34")
    private func looksLikeVersionString(_ str: String) -> Bool {
        guard !str.isEmpty else { return false }
        let allowed = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
        guard str.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return str.contains(".") && str.first?.isNumber == true
    }

    private func resolveUsername(uid: uid_t) -> String {
        if let pw = getpwuid(uid) {
            return String(cString: pw.pointee.pw_name)
        }
        return "\(uid)"
    }

    private func processStatus(_ stat: Int32) -> String {
        switch stat {
        case 1: return "Idle"
        case 2: return "Running"
        case 3: return "Sleeping"
        case 4: return "Stopped"
        case 5: return "Zombie"
        default: return "Unknown"
        }
    }
}
