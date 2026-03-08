import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            detailView
        }
    }

    private var sidebar: some View {
        List(selection: $selectedItem) {
            ForEach(NavigationSection.allCases, id: \.self) { section in
                Section(section.rawValue) {
                    ForEach(NavigationItem.items(for: section), id: \.self) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .cacheCleaner:
            CacheCleanerView()
        case .browserCleanup:
            BrowserCleanupView()
        case .largeFileFinder:
            LargeFileFinderView()
        case .processManager:
            ProcessManagerView()
        case .startupItems:
            StartupItemsView()
        case .memoryOptimizer:
            MemoryOptimizerView()
        case .dnsFlush:
            DNSFlushView()
        case .none:
            ContentUnavailableView(
                "Select a Feature",
                systemImage: "sidebar.left",
                description: Text("Choose a tool from the sidebar to get started.")
            )
        }
    }
}
