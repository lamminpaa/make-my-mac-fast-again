import SwiftUI

struct LargeFileFinderView: View {
    @State private var viewModel = LargeFileFinderViewModel()
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(title: "Large File Finder", subtitle: "Find and remove large files from your home directory") {
                Picker("Min size:", selection: $viewModel.selectedMinSize) {
                    ForEach(LargeFileFinderViewModel.MinFileSize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .frame(width: 180)

                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)

                    Button("Cancel") {
                        viewModel.cancelScan()
                    }
                } else {
                    Button("Scan") {
                        Task { await viewModel.scan() }
                    }
                }

                if !viewModel.files.isEmpty {
                    Button("Select All") {
                        viewModel.selectedFileIDs = Set(viewModel.files.map(\.id))
                    }
                    Button("Select None") {
                        viewModel.selectedFileIDs = []
                    }
                }

                Button("Move to Trash") {
                    showConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(viewModel.selectedFileIDs.isEmpty)
            }

            if viewModel.files.isEmpty && !viewModel.isScanning {
                ContentUnavailableView(
                    "No Large Files Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Click Scan to search for large files in your home directory.")
                )
                .frame(maxHeight: .infinity)
            } else if viewModel.files.isEmpty && viewModel.isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Scanning \(viewModel.filesScanned) files...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    fileTypeBreakdownSummary

                    Table(viewModel.files, selection: $viewModel.selectedFileIDs) {
                        TableColumn("Name") { file in
                            Text(file.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .width(min: 200)

                        TableColumn("Size") { file in
                            Text(ByteFormatter.format(file.size))
                                .monospacedDigit()
                        }
                        .width(80)

                        TableColumn("Path") { file in
                            Text(file.path)
                                .lineLimit(1)
                                .truncationMode(.head)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .width(min: 200)

                        TableColumn("Modified") { file in
                            Text(file.modifiedDate, style: .date)
                                .foregroundStyle(.secondary)
                        }
                        .width(100)

                        TableColumn("") { file in
                            Button("Reveal") {
                                viewModel.revealInFinder(file)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                        .width(60)
                    }
                }
            }

            StatusBar(
                message: viewModel.isScanning ? "Scanned \(viewModel.filesScanned) files..." : viewModel.statusMessage,
                isLoading: viewModel.isScanning
            ) {
                if !viewModel.selectedFileIDs.isEmpty {
                    Text("\(viewModel.selectedFileIDs.count) selected (\(ByteFormatter.format(viewModel.totalSelectedSize)))")
                        .font(.caption.bold())
                }
            }
        }
        .alert("Confirm Move to Trash", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                Task { await viewModel.moveToTrash() }
            }
        } message: {
            Text("Move \(viewModel.selectedFileIDs.count) files (\(ByteFormatter.format(viewModel.totalSelectedSize))) to Trash?")
        }
    }

    private var fileTypeBreakdownSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(viewModel.files.count) files found")
                    .font(.callout.bold())
                Text("(\(ByteFormatter.format(viewModel.totalFilesSize)) total)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if !viewModel.typeBreakdown.isEmpty {
                HStack(spacing: 12) {
                    ForEach(viewModel.typeBreakdown) { breakdown in
                        HStack(spacing: 4) {
                            Image(systemName: typeIcon(breakdown.type))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(breakdown.type)
                                    .font(.caption.bold())
                                Text("\(breakdown.count) files, \(ByteFormatter.format(breakdown.totalSize))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func typeIcon(_ type: String) -> String {
        switch type {
        case "Videos": return "film"
        case "Disk Images": return "opticaldiscdrive"
        case "Archives": return "archivebox"
        case "Applications": return "app"
        case "Documents": return "doc.text"
        default: return "doc"
        }
    }

}
