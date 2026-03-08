import SwiftUI

struct BrowserCleanupView: View {
    @State private var viewModel = BrowserCleanupViewModel()
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if viewModel.browsers.isEmpty {
                ContentUnavailableView(
                    "Detecting browsers...",
                    systemImage: "globe"
                )
            } else {
                List {
                    ForEach(viewModel.browsers.filter(\.isInstalled)) { browser in
                        browserRow(browser)
                    }

                    if viewModel.browsers.allSatisfy({ !$0.isInstalled }) {
                        ContentUnavailableView(
                            "No supported browsers detected",
                            systemImage: "globe"
                        )
                    }
                }
            }

            statusBar
        }
        .task {
            viewModel.loadBrowsers()
            await viewModel.scanSizes()
        }
        .alert("Confirm Browser Cleanup", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task { await viewModel.cleanBrowsers() }
            }
        } message: {
            var msg = "This will delete browser"
            if viewModel.cleanCache { msg += " cache" }
            if viewModel.cleanCookies { msg += " and cookies" }
            msg += ". Close browsers first for best results."
            return Text(msg)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Browser Cleanup")
                    .font(.title2.bold())
                Text("Clear browser caches and cookies")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Cache", isOn: $viewModel.cleanCache)
            Toggle("Cookies", isOn: $viewModel.cleanCookies)

            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Clean All") {
                showConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.totalCacheSize == 0 || viewModel.isCleaning)
        }
        .padding()
    }

    private func browserRow(_ browser: BrowserProfile) -> some View {
        HStack {
            Text(browser.browser)
                .font(.body.bold())

            Spacer()

            Text(ByteFormatter.format(browser.cacheSize))
                .font(.body.monospacedDigit())
                .foregroundStyle(browser.cacheSize > 0 ? .primary : .secondary)
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
            Text("Total: \(ByteFormatter.format(viewModel.totalCacheSize))")
                .font(.caption.bold())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
