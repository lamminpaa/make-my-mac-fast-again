import SwiftUI

struct BrowserCleanupView: View {
    @State private var viewModel = BrowserCleanupViewModel()
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(title: "Browser Cleanup", subtitle: "Clear browser caches and cookies") {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Cache", isOn: $viewModel.cleanCache)
                    Text("Temporary files stored for faster page loads")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Cookies", isOn: $viewModel.cleanCookies)
                    Text("Login sessions and site preferences")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

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
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            StatusBar(message: viewModel.statusMessage, isLoading: viewModel.isCleaning) {
                if viewModel.totalCacheSize > 0 {
                    Text("Total: \(ByteFormatter.format(viewModel.totalCacheSize))")
                        .font(.caption.bold())
                }
            }
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

    /// Maps a browser name to its corresponding SF Symbol icon name.
    private func browserIcon(_ name: String) -> String {
        switch name {
        case "Safari":
            return "safari"
        case "Google Chrome":
            return "globe"
        case "Firefox":
            return "flame"
        case "Microsoft Edge":
            return "globe"
        case "Arc":
            return "globe"
        case "Brave":
            return "shield"
        default:
            return "globe"
        }
    }

    private func browserRow(_ browser: BrowserProfile) -> some View {
        HStack {
            Image(systemName: browserIcon(browser.browser))
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(browser.browser)
                .font(.body.bold())

            if viewModel.isBrowserRunning(browser.browser) {
                Label("Running", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help("Close \(browser.browser) before cleaning for best results")
            }

            Spacer()

            Text(ByteFormatter.format(browser.cacheSize))
                .font(.body.monospacedDigit())
                .foregroundStyle(browser.cacheSize > 0 ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }

}
