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
    case startupItems = "Startup Items"
    case memoryOptimizer = "Memory Optimizer"
    case dnsFlush = "DNS Flush"

    var section: NavigationSection {
        switch self {
        case .dashboard:
            return .overview
        case .cacheCleaner, .browserCleanup, .largeFileFinder:
            return .cleanup
        case .processManager, .startupItems, .memoryOptimizer, .dnsFlush:
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
        case .startupItems: return "6"
        case .memoryOptimizer: return "7"
        case .dnsFlush: return "8"
        }
    }

    static func items(for section: NavigationSection) -> [NavigationItem] {
        NavigationItem.allCases.filter { $0.section == section }
    }
}
