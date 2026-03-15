import AppKit
import Foundation

@MainActor
@Observable
final class StartupItemsViewModel {
    var items: [StartupItem] = []
    var isLoading = false
    var statusMessage = ""
    var runningStatus: [String: Bool] = [:]
    var impactLevel: [String: String] = [:]

    private let shell = ShellExecutor()
    private let privilegedExecutor = PrivilegedExecutor()

    func loadItems() async {
        isLoading = true
        items = []
        runningStatus = [:]
        impactLevel = [:]

        let loadedLabels = await getLoadedLabels()
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // User LaunchAgents
        let userAgentPath = "\(home)/Library/LaunchAgents"
        loadPlistsFrom(path: userAgentPath, type: .userAgent, loadedLabels: loadedLabels)

        // Global LaunchAgents
        loadPlistsFrom(path: "/Library/LaunchAgents", type: .globalAgent, loadedLabels: loadedLabels)

        // Global LaunchDaemons
        loadPlistsFrom(path: "/Library/LaunchDaemons", type: .globalDaemon, loadedLabels: loadedLabels)

        await checkRunningStatus()

        isLoading = false
        statusMessage = "Found \(items.count) startup items."
    }

    private func getLoadedLabels() async -> Set<String> {
        do {
            let result = try await shell.run("launchctl list")
            var labels = Set<String>()
            for line in result.output.split(separator: "\n").dropFirst() {
                let parts = line.split(separator: "\t")
                if parts.count >= 3 {
                    labels.insert(String(parts[2]))
                }
            }
            return labels
        } catch {
            return []
        }
    }

    private func loadPlistsFrom(path: String, type: StartupItemType, loadedLabels: Set<String>) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: path) else { return }

        for file in files where file.hasSuffix(".plist") {
            let fullPath = "\(path)/\(file)"

            guard let data = fm.contents(atPath: fullPath),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                continue
            }

            let label = plist["Label"] as? String ?? file.replacingOccurrences(of: ".plist", with: "")
            let disabled = plist["Disabled"] as? Bool ?? false

            let isLoaded = loadedLabels.contains(label)

            let name = label.components(separatedBy: ".").last ?? label

            // Determine impact level based on plist keys
            let keepAlive = plist["KeepAlive"]
            let runAtLoad = plist["RunAtLoad"] as? Bool ?? false

            if keepAlive != nil {
                impactLevel[label] = "High"
            } else if runAtLoad {
                impactLevel[label] = "Medium"
            } else {
                impactLevel[label] = "Low"
            }

            items.append(StartupItem(
                name: name.capitalized,
                path: fullPath,
                label: label,
                isEnabled: !disabled && isLoaded,
                type: type
            ))
        }
    }

    func checkRunningStatus() async {
        do {
            let result = try await shell.run("launchctl list")
            var pidByLabel: [String: String] = [:]
            for line in result.output.split(separator: "\n").dropFirst() {
                let parts = line.split(separator: "\t")
                if parts.count >= 3 {
                    let pidStr = String(parts[0])
                    let label = String(parts[2])
                    // A PID of "-" means the service is not currently running
                    pidByLabel[label] = pidStr
                }
            }

            for item in items {
                if let pidStr = pidByLabel[item.label], pidStr != "-" {
                    runningStatus[item.label] = true
                } else {
                    runningStatus[item.label] = false
                }
            }
        } catch {
            // If we can't check, mark all as unknown (false)
            for item in items {
                runningStatus[item.label] = false
            }
        }
    }

    func toggleItem(_ item: StartupItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        let action: LaunchctlAction = item.isEnabled ? .disable : .enable

        do {
            let domain: String
            switch item.type {
            case .userAgent:
                let uid = getuid()
                domain = "gui/\(uid)"
            case .globalAgent, .globalDaemon:
                domain = "system"
            }

            switch item.type {
            case .userAgent:
                let command = "launchctl \(action.rawValue) \(domain)/\(item.label)"
                _ = try await shell.run(command)
            case .globalAgent, .globalDaemon:
                _ = try await privilegedExecutor.run(
                    .launchctl(action: action, domain: domain, label: item.label)
                )
            }

            items[index].isEnabled.toggle()
            statusMessage = "\(item.name) \(items[index].isEnabled ? "enabled" : "disabled")."
        } catch {
            statusMessage = "Failed to \(action.rawValue) \(item.name): \(error.localizedDescription)"
        }
    }

    func revealInFinder(_ item: StartupItem) {
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
