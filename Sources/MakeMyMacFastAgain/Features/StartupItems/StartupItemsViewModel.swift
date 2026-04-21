import AppKit
import Foundation
import os

@MainActor
@Observable
final class StartupItemsViewModel {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "startup-items")
    var items: [StartupItem] = []
    var isLoading = false
    var statusMessage = ""
    var runningStatus: [String: Bool] = [:]
    var impactLevel: [String: String] = [:]

    // Optimizer state.
    var isOptimizerPresented = false
    /// True while `applyOptimization` or `undoLastOptimization` is in flight.
    /// The view uses this to disable the Optimize/Undo buttons to prevent
    /// overlapping concurrent operations from racing on `items`.
    var isOptimizerBusy = false
    /// Most recent successful optimization, kept in-memory so the user can
    /// undo with a single click. Cleared when the view reloads.
    var lastOptimization: [OptimizationEntry] = []

    struct OptimizationEntry: Sendable, Identifiable {
        let id = UUID()
        let label: String
        let name: String
        let type: StartupItemType
        let previousEnabled: Bool
    }

    private weak var appState: AppState?
    private let shell = ShellExecutor()
    private let privilegedExecutor = PrivilegedExecutor()

    func bind(to appState: AppState) {
        self.appState = appState
    }

    func loadItems() async {
        isLoading = true
        items = []
        runningStatus = [:]
        impactLevel = [:]
        lastOptimization = []

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
        logger.info("Found \(self.items.count, privacy: .public) startup items")
        statusMessage = "Found \(items.count) startup items."
        reportToAppState()
    }

    private func reportToAppState() {
        let enabledItems = items.filter(\.isEnabled)
        appState?.totalEnabledStartupItems = enabledItems.count
        appState?.enabledHighImpactStartupItems = enabledItems.filter { item in
            let level = impactLevel[item.label] ?? "Low"
            return level == "High" || level == "Medium"
        }.count
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

            let category = StartupItemClassifier.classify(label: label, path: fullPath, type: type)

            items.append(StartupItem(
                name: name.capitalized,
                path: fullPath,
                label: label,
                isEnabled: !disabled && isLoaded,
                type: type,
                category: category
            ))
        }
    }

    /// Items the optimizer is willing to propose disabling. `.appleSystem`
    /// and `.safetyCritical` are filtered out unconditionally; already-disabled
    /// items are skipped since there's nothing to optimize.
    var optimizationCandidates: [StartupItem] {
        items.filter { item in
            guard item.isEnabled else { return false }
            return item.category == .convenience || item.category == .unknown
        }
    }

    /// Default pre-selection for the optimizer sheet. Only pre-selects
    /// `.convenience` — `.unknown` requires explicit user opt-in.
    func defaultPreselection() -> Set<UUID> {
        Set(optimizationCandidates.filter { $0.category == .convenience }.map(\.id))
    }

    /// Disable every item whose UUID is in `selectedIDs`. Records the reverse
    /// operation in `lastOptimization` so the user can undo. Errors on any
    /// individual item are logged but don't abort the batch.
    func applyOptimization(_ selectedIDs: Set<UUID>) async {
        guard !selectedIDs.isEmpty else { return }
        guard !isOptimizerBusy else {
            logger.info("applyOptimization ignored: optimizer already busy")
            return
        }
        isOptimizerBusy = true
        defer { isOptimizerBusy = false }

        var undo: [OptimizationEntry] = []
        var succeeded = 0
        var failed = 0

        for item in items where selectedIDs.contains(item.id) {
            let previousEnabled = item.isEnabled
            guard previousEnabled else { continue }

            let before = item.isEnabled
            await toggleItem(item)
            let after = items.first(where: { $0.id == item.id })?.isEnabled ?? before

            if after != before {
                undo.append(OptimizationEntry(
                    label: item.label,
                    name: item.name,
                    type: item.type,
                    previousEnabled: previousEnabled
                ))
                succeeded += 1
            } else {
                failed += 1
            }
        }

        lastOptimization = undo

        if failed == 0 {
            statusMessage = "Disabled \(succeeded) startup item\(succeeded == 1 ? "" : "s")."
        } else {
            statusMessage = "Disabled \(succeeded), \(failed) failed. See console for details."
        }
        logger.info("Optimization: \(succeeded, privacy: .public) disabled, \(failed, privacy: .public) failed")
        reportToAppState()
    }

    /// Re-enable every item captured in `lastOptimization`, in reverse order.
    func undoLastOptimization() async {
        guard !lastOptimization.isEmpty else { return }
        guard !isOptimizerBusy else {
            logger.info("undoLastOptimization ignored: optimizer already busy")
            return
        }
        isOptimizerBusy = true
        defer { isOptimizerBusy = false }

        let entries = lastOptimization
        var restored = 0
        var skipped = 0

        for entry in entries.reversed() {
            guard let item = items.first(where: { $0.label == entry.label && $0.type == entry.type }) else {
                skipped += 1
                continue
            }
            if item.isEnabled {
                // User manually re-enabled it between apply and undo.
                logger.info("Undo skipping \(entry.label, privacy: .public): already enabled")
                skipped += 1
                continue
            }
            await toggleItem(item)
            restored += 1
        }

        if skipped == 0 {
            statusMessage = "Restored \(restored) startup item\(restored == 1 ? "" : "s")."
        } else {
            statusMessage = "Restored \(restored), skipped \(skipped) (state changed since apply)."
        }
        lastOptimization = []
        logger.info("Undo: restored \(restored, privacy: .public), skipped \(skipped, privacy: .public)")
        reportToAppState()
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
                _ = try await shell.run(
                    executablePath: "/bin/launchctl",
                    arguments: [action.rawValue, "\(domain)/\(item.label)"]
                )
            case .globalAgent, .globalDaemon:
                _ = try await privilegedExecutor.run(
                    .launchctl(action: action, domain: domain, label: item.label)
                )
            }

            items[index].isEnabled.toggle()
            let status = items[index].isEnabled ? "enabled" : "disabled"
            logger.info("\(item.label, privacy: .public) \(status, privacy: .public)")
            statusMessage = "\(item.name) \(status)."
            reportToAppState()
        } catch {
            logger.warning("Failed to \(action.rawValue, privacy: .public) \(item.label, privacy: .public): \(error.localizedDescription)")
            statusMessage = "Failed to \(action.rawValue) \(item.name): \(error.localizedDescription)"
        }
    }

    func revealInFinder(_ item: StartupItem) {
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
