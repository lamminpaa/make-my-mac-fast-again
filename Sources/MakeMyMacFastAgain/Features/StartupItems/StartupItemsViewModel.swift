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

        let loadedLabels = await getLoadedLabels()
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // User LaunchAgents
        let userAgentPath = "\(home)/Library/LaunchAgents"
        loadPlistsFrom(path: userAgentPath, type: .userAgent, loadedLabels: loadedLabels)

        // Global LaunchAgents
        loadPlistsFrom(path: "/Library/LaunchAgents", type: .globalAgent, loadedLabels: loadedLabels)

        // Global LaunchDaemons
        loadPlistsFrom(path: "/Library/LaunchDaemons", type: .globalDaemon, loadedLabels: loadedLabels)

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

            items.append(StartupItem(
                name: name.capitalized,
                path: fullPath,
                label: label,
                isEnabled: !disabled && isLoaded,
                type: type
            ))
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
