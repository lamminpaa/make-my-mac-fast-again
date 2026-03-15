import SwiftUI

struct CacheCleanerView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = CacheCleanerViewModel()
    @State private var showCleanPreview = false
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(title: "Cache Cleaner", subtitle: "Remove cached files to free up disk space") {
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)

                    Button("Cancel") {
                        viewModel.cancelScan()
                    }
                } else {
                    Button("Rescan") {
                        Task { await viewModel.scanSizes() }
                    }
                    .disabled(viewModel.isCleaning)
                }

                if !viewModel.categories.isEmpty {
                    Button("Select All") { viewModel.selectAll() }
                    Button("Deselect All") { viewModel.deselectAll() }
                }

                Button("Clean Selected", role: .destructive) {
                    if AppSettings.load().confirmBeforeCleanup {
                        showCleanPreview = true
                    } else {
                        Task { await viewModel.cleanSelected() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.totalSelectedSize == 0 || viewModel.isCleaning)
            }

            if viewModel.categories.isEmpty {
                ContentUnavailableView(
                    "Loading cache categories...",
                    systemImage: "arrow.clockwise"
                )
            } else {
                List {
                    ForEach(viewModel.categories.indices, id: \.self) { index in
                        cacheRow(index: index)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            StatusBar(message: viewModel.statusMessage, isLoading: viewModel.isCleaning) {
                Text("Total: \(ByteFormatter.format(viewModel.totalSize))")
                    .font(.caption.bold())
            }
        }
        .task {
            if let appState {
                viewModel.bind(to: appState)
            }
            viewModel.loadCategories()
            await viewModel.scanSizes()
        }
        .sheet(isPresented: $showCleanPreview) {
            CleanPreviewSheet(
                categories: viewModel.categories.filter { $0.isSelected && $0.size > 0 },
                totalSize: viewModel.totalSelectedSize
            ) {
                showCleanPreview = false
                Task { await viewModel.cleanSelected() }
            } onCancel: {
                showCleanPreview = false
            }
        }
    }

    private func cacheRow(index: Int) -> some View {
        let category = viewModel.categories[index]
        let isExpanded = expandedCategories.contains(category.name)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    toggleExpansion(for: index)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $viewModel.categories[index].isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.body.bold())
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let count = viewModel.fileCount[category.name] {
                    Text("\(count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if category.requiresAdmin {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.orange)
                        .help("Requires administrator privileges")
                }

                if viewModel.isScanning && category.size == 0 {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(ByteFormatter.format(category.size))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(category.size > 0 ? .primary : .secondary)
                }
            }
            .padding(.vertical, 4)

            if isExpanded {
                subdirectoryList(for: category.name)
            }
        }
    }

    private func toggleExpansion(for index: Int) {
        let name = viewModel.categories[index].name
        if expandedCategories.contains(name) {
            expandedCategories.remove(name)
        } else {
            expandedCategories.insert(name)
            // Load details if not yet loaded
            if viewModel.categoryDetails[name] == nil {
                Task { await viewModel.loadCategoryDetails(for: index) }
            }
        }
    }

    @ViewBuilder
    private func subdirectoryList(for categoryName: String) -> some View {
        if let details = viewModel.categoryDetails[categoryName] {
            if details.isEmpty {
                Text("No subdirectories found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 48)
                    .padding(.vertical, 2)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(details, id: \.name) { item in
                        HStack {
                            Image(systemName: "folder")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(ByteFormatter.format(item.size))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 48)
                .padding(.vertical, 4)
            }
        } else {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading details...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 48)
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Clean Preview Sheet

private struct CleanPreviewSheet: View {
    let categories: [CacheCategory]
    let totalSize: UInt64
    let onClean: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.largeTitle)
                    .foregroundStyle(.red)

                Text("Before You Clean")
                    .font(.headline)

                Text("The following items will be permanently deleted:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            List {
                ForEach(categories) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.body)
                            Text(category.paths.first ?? "")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(ByteFormatter.format(category.size))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 120, maxHeight: 250)

            Divider()

            HStack {
                Text("Total to free:")
                    .font(.headline)
                Spacer()
                Text(ByteFormatter.format(totalSize))
                    .font(.headline.monospacedDigit())
            }
            .padding()

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Clean", role: .destructive, action: onClean)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
        }
        .frame(width: 420)
    }
}
