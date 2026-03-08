import SwiftUI

struct StartupItemsView: View {
    @State private var viewModel = StartupItemsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if viewModel.items.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Startup Items Found",
                    systemImage: "arrow.right.circle",
                    description: Text("No LaunchAgents or LaunchDaemons were detected.")
                )
            } else {
                List {
                    ForEach(StartupItemType.allCases, id: \.self) { type in
                        let typeItems = viewModel.items.filter { $0.type == type }
                        if !typeItems.isEmpty {
                            Section(type.rawValue) {
                                ForEach(typeItems) { item in
                                    startupRow(item)
                                }
                            }
                        }
                    }
                }
            }

            statusBar
        }
        .task {
            await viewModel.loadItems()
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Startup Items")
                    .font(.title2.bold())
                Text("Manage LaunchAgents and LaunchDaemons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Reload") {
                Task { await viewModel.loadItems() }
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }

    private func startupRow(_ item: StartupItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.bold())
                Text(item.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reveal") {
                viewModel.revealInFinder(item)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { _ in
                    Task { await viewModel.toggleItem(item) }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.items.count) items")
                .font(.caption.bold())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

extension StartupItemType: CaseIterable {
    static let allCases: [StartupItemType] = [.userAgent, .globalAgent, .globalDaemon]
}
