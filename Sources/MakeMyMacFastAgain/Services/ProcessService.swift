import Foundation
import CSystemKit

@MainActor
final class ProcessService {
    func listProcesses() -> [AppProcessInfo] {
        var pids = [pid_t](repeating: 0, count: 2048)
        let count = csk_get_all_pids(&pids, Int32(pids.count))

        guard count > 0 else { return [] }

        var processes: [AppProcessInfo] = []

        for i in 0..<Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var info = CSKProcessInfo()
            var usage = CSKProcessResourceUsage()

            guard csk_get_process_info(pid, &info) == 0 else { continue }

            let name = withUnsafePointer(to: &info.name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 256) { charPtr in
                    String(cString: charPtr)
                }
            }

            guard !name.isEmpty else { continue }

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
                name: name,
                user: user,
                cpuUsage: cpuTime,
                memoryBytes: memoryBytes,
                status: processStatus(info.status)
            ))
        }

        return processes
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
