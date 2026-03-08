import SwiftUI

struct CacheCleanerView: View {
    @State private var viewModel = CacheCleanerViewModel()
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

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

            statusBar
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

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Cache Cleaner")
                    .font(.title2.bold())
                Text("Remove cached files to free up disk space")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
        .padding()
    }

    private func cacheRow(index: Int) -> some View {
        HStack {
            Toggle("", isOn: $viewModel.categories[index].isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.categories[index].name)
                    .font(.body.bold())
                Text(viewModel.categories[index].description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.categories[index].requiresAdmin {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                    .help("Requires administrator privileges")
            }

            Text(ByteFormatter.format(viewModel.categories[index].size))
                .font(.body.monospacedDigit())
                .foregroundStyle(viewModel.categories[index].size > 0 ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }

    private var statusBar: some View {
        HStack {
            if viewModel.isCleaning {
                ProgressView()
                    .controlSize(.small)
            }
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Total: \(ByteFormatter.format(viewModel.totalSize))")
                .font(.caption.bold())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
