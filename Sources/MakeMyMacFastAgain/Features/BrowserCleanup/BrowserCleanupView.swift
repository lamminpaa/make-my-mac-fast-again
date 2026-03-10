import AppKit
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

                Button("Clean All", role: .destructive) {
                    showConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.totalCacheSize == 0 || viewModel.isCleaning)
            }

            if viewModel.browsers.isEmpty {
                ContentUnavailableView(
                    "Detecting browsers...",
                    systemImage: "globe"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        let installedBrowsers = viewModel.browsers.filter(\.isInstalled)
                        if installedBrowsers.isEmpty {
                            ContentUnavailableView(
                                "No supported browsers detected",
                                systemImage: "globe"
                            )
                        } else {
                            ForEach(installedBrowsers) { browser in
                                browserRow(browser)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                if browser.id != installedBrowsers.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
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
        .alert("Delete \(ByteFormatter.format(viewModel.totalCacheSize)) of Browser Data?", isPresented: $showConfirmation) {
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

    private func browserAppIcon(_ name: String) -> NSImage? {
        let appPaths: [String: String] = [
            "Safari": "/Applications/Safari.app",
            "Google Chrome": "/Applications/Google Chrome.app",
            "Firefox": "/Applications/Firefox.app",
            "Microsoft Edge": "/Applications/Microsoft Edge.app",
            "Arc": "/Applications/Arc.app",
            "Brave": "/Applications/Brave Browser.app",
        ]
        guard let path = appPaths[name] else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private func browserRow(_ browser: BrowserProfile) -> some View {
        HStack {
            if let icon = browserAppIcon(browser.browser) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

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
