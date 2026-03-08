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
        .onAppear {
            ScreenshotController.shared.onSelectItem = { item in
                selectedItem = item
            }
        }
        .background {
            navigationShortcuts
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

    /// Hidden buttons that capture Cmd+1 through Cmd+8 keyboard shortcuts
    /// for quick sidebar navigation.
    private var navigationShortcuts: some View {
        Group {
            Button("") { selectedItem = .dashboard }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { selectedItem = .cacheCleaner }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { selectedItem = .browserCleanup }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { selectedItem = .largeFileFinder }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { selectedItem = .processManager }
                .keyboardShortcut("5", modifiers: .command)
            Button("") { selectedItem = .startupItems }
                .keyboardShortcut("6", modifiers: .command)
            Button("") { selectedItem = .memoryOptimizer }
                .keyboardShortcut("7", modifiers: .command)
            Button("") { selectedItem = .dnsFlush }
                .keyboardShortcut("8", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
    }
}
