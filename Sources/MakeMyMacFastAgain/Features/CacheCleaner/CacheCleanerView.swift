import SwiftUI

struct CacheCleanerView: View {
    @State private var viewModel = CacheCleanerViewModel()
    @State private var showConfirmation = false
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(title: "Cache Cleaner", subtitle: "Remove cached files to free up disk space") {
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }

                Button("Rescan") {
                    Task { await viewModel.scanSizes() }
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                Button("Clean Selected") {
                    showConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
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
            }

            StatusBar(message: viewModel.statusMessage, isLoading: viewModel.isCleaning) {
                Text("Total: \(ByteFormatter.format(viewModel.totalSize))")
                    .font(.caption.bold())
            }
        }
        .task {
            viewModel.loadCategories()
            await viewModel.scanSizes()
        }
        .alert("Confirm Cleanup", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task { await viewModel.cleanSelected() }
            }
        } message: {
            Text("This will permanently delete \(ByteFormatter.format(viewModel.totalSelectedSize)) of cached data. This action cannot be undone.")
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

                Text(ByteFormatter.format(category.size))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(category.size > 0 ? .primary : .secondary)
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
