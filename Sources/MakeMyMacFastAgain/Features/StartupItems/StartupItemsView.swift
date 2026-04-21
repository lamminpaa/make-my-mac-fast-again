import SwiftUI

struct StartupItemsView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = StartupItemsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(title: "Startup Items", subtitle: "Manage LaunchAgents and LaunchDaemons") {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                if !viewModel.lastOptimization.isEmpty {
                    Button("Undo (\(viewModel.lastOptimization.count))") {
                        Task { await viewModel.undoLastOptimization() }
                    }
                    .disabled(viewModel.isLoading || viewModel.isOptimizerBusy)
                }

                Button("Optimize...") {
                    viewModel.isOptimizerPresented = true
                }
                .disabled(viewModel.isLoading || viewModel.isOptimizerBusy || viewModel.optimizationCandidates.isEmpty)

                Button("Reload") {
                    Task { await viewModel.loadItems() }
                }
                .disabled(viewModel.isLoading || viewModel.isOptimizerBusy)
            }

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
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            StatusBar(message: viewModel.statusMessage, isLoading: false) {
                Text("\(viewModel.items.count) items")
                    .font(.caption.bold())
            }
        }
        .task {
            if let appState {
                viewModel.bind(to: appState)
            }
            await viewModel.loadItems()
        }
        .sheet(isPresented: $viewModel.isOptimizerPresented) {
            StartupOptimizerSheet(
                candidates: viewModel.optimizationCandidates,
                initialSelection: viewModel.defaultPreselection(),
                onApply: { selection in
                    viewModel.isOptimizerPresented = false
                    Task { await viewModel.applyOptimization(selection) }
                },
                onCancel: {
                    viewModel.isOptimizerPresented = false
                }
            )
        }
    }

    private func startupRow(_ item: StartupItem) -> some View {
        HStack {
            // Running status indicator
            Circle()
                .fill(viewModel.runningStatus[item.label] == true ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .help(viewModel.runningStatus[item.label] == true ? "Running" : "Not running")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body.bold())

                    impactBadge(for: item.label)
                    categoryBadge(item.category)
                }
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

    @ViewBuilder
    private func impactBadge(for label: String) -> some View {
        if let impact = viewModel.impactLevel[label] {
            Text(impact)
                .font(.caption2.bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(impactColor(impact).opacity(0.15))
                .foregroundStyle(impactColor(impact))
                .clipShape(Capsule())
        }
    }

    private func impactColor(_ impact: String) -> Color {
        switch impact {
        case "High": return .red
        case "Medium": return .orange
        default: return .green
        }
    }

    @ViewBuilder
    private func categoryBadge(_ category: StartupCategory) -> some View {
        Text(category.shortLabel)
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(categoryColor(category).opacity(0.15))
            .foregroundStyle(categoryColor(category))
            .clipShape(Capsule())
            .help(category.explanation)
    }

    private func categoryColor(_ category: StartupCategory) -> Color {
        switch category {
        case .appleSystem: return .gray
        case .safetyCritical: return .red
        case .convenience: return .blue
        case .unknown: return .orange
        }
    }
}

extension StartupItemType: CaseIterable {
    static let allCases: [StartupItemType] = [.userAgent, .globalAgent, .globalDaemon]
}
