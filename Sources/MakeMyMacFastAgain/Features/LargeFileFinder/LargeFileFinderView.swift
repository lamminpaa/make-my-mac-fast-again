import SwiftUI

struct LargeFileFinderView: View {
    @State private var viewModel = LargeFileFinderViewModel()
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

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

            statusBar
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

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Large File Finder")
                    .font(.title2.bold())
                Text("Find and remove large files from your home directory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Min size:", selection: $viewModel.selectedMinSize) {
                ForEach(LargeFileFinderViewModel.MinFileSize.allCases, id: \.self) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .frame(width: 180)

            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Scan") {
                Task { await viewModel.scan() }
            }
            .disabled(viewModel.isScanning)

            Button("Move to Trash") {
                showConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.selectedFileIDs.isEmpty)
        }
        .padding()
    }

    private var statusBar: some View {
        HStack {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                Text("Scanned \(viewModel.filesScanned) files...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !viewModel.selectedFileIDs.isEmpty {
                Text("\(viewModel.selectedFileIDs.count) selected (\(ByteFormatter.format(viewModel.totalSelectedSize)))")
                    .font(.caption.bold())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
