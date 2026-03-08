import Foundation

@MainActor
@Observable
final class StartupItemsViewModel {
    var items: [StartupItem] = []
    var isLoading = false
    var statusMessage = ""

    private let shell = ShellExecutor()

    func loadItems() async {
        isLoading = true
        items = []

        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // User LaunchAgents
        let userAgentPath = "\(home)/Library/LaunchAgents"
        await loadPlistsFrom(path: userAgentPath, type: .userAgent)

        // Global LaunchAgents
        await loadPlistsFrom(path: "/Library/LaunchAgents", type: .globalAgent)

        // Global LaunchDaemons
        await loadPlistsFrom(path: "/Library/LaunchDaemons", type: .globalDaemon)

        isLoading = false
        statusMessage = "Found \(items.count) startup items."
    }

    private func loadPlistsFrom(path: String, type: StartupItemType) async {
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

            // Check if loaded via launchctl
            let isLoaded = await checkIfLoaded(label: label, type: type)

            let name = label.components(separatedBy: ".").last ?? label

            items.append(StartupItem(
                name: name.capitalized,
                path: fullPath,
                label: label,
                isEnabled: !disabled && isLoaded,
                type: type
            ))
        }
    }

    private func checkIfLoaded(label: String, type: StartupItemType) async -> Bool {
        do {
            let domain: String
            switch type {
            case .userAgent:
                let uid = getuid()
                domain = "gui/\(uid)/\(label)"
            case .globalAgent, .globalDaemon:
                domain = "system/\(label)"
            }

            let result = try await shell.run("launchctl print \(domain) 2>/dev/null")
            return result.succeeded
        } catch {
            return false
        }
    }

    func toggleItem(_ item: StartupItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        let action = item.isEnabled ? "disable" : "enable"

        do {
            let domain: String
            switch item.type {
            case .userAgent:
                let uid = getuid()
                domain = "gui/\(uid)"
            case .globalAgent, .globalDaemon:
                domain = "system"
            }

            _ = try await shell.run("launchctl \(action) \(domain)/\(item.label)")
            items[index].isEnabled.toggle()
            statusMessage = "\(item.name) \(items[index].isEnabled ? "enabled" : "disabled")."
        } catch {
            statusMessage = "Failed to \(action) \(item.name): \(error.localizedDescription)"
        }
    }

    func revealInFinder(_ item: StartupItem) {
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}

import AppKit
