import SwiftUI

enum NavigationSection: String, CaseIterable {
    case overview = "Overview"
    case cleanup = "Cleanup"
    case system = "System"
}

enum NavigationItem: String, Hashable, CaseIterable {
    case dashboard = "Dashboard"
    case cacheCleaner = "Cache Cleaner"
    case browserCleanup = "Browser Cleanup"
    case largeFileFinder = "Large File Finder"
    case processManager = "Process Manager"
    case zombiePollers = "Zombie Pollers"
    case startupItems = "Startup Items"
    case memoryOptimizer = "Memory Optimizer"
    case dnsFlush = "DNS Flush"

    var section: NavigationSection {
        switch self {
        case .dashboard:
            return .overview
        case .cacheCleaner, .browserCleanup, .largeFileFinder:
            return .cleanup
        case .processManager, .zombiePollers, .startupItems, .memoryOptimizer, .dnsFlush:
            return .system
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .cacheCleaner: return "trash"
        case .browserCleanup: return "globe"
        case .largeFileFinder: return "doc.text.magnifyingglass"
        case .processManager: return "cpu"
        case .zombiePollers: return "ant"
        case .startupItems: return "arrow.right.circle"
        case .memoryOptimizer: return "memorychip"
        case .dnsFlush: return "network"
        }
    }

    var shortcutHint: String? {
        switch self {
        case .dashboard: return "1"
        case .cacheCleaner: return "2"
        case .browserCleanup: return "3"
        case .largeFileFinder: return "4"
        case .processManager: return "5"
        case .zombiePollers: return "6"
        case .startupItems: return "7"
        case .memoryOptimizer: return "8"
        case .dnsFlush: return "9"
        }
    }

    static func items(for section: NavigationSection) -> [NavigationItem] {
        NavigationItem.allCases.filter { $0.section == section }
    }
}

extension Notification.Name {
    /// Posted to request the sidebar to switch to a specific NavigationItem.
    /// The item is carried as the notification's `object`. Used for in-app
    /// deep links like Dashboard → Zombie Pollers.
    static let requestNavigate = Notification.Name("io.tunk.make-my-mac-fast-again.requestNavigate")
}
