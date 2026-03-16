import SwiftUI

struct DNSFlushView: View {
    @State private var viewModel = DNSFlushViewModel()

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(title: "DNS Cache Flush", subtitle: "Resolve connectivity issues by clearing stale DNS records") {
                if viewModel.isFlushing || viewModel.isTestingServers {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Test Servers") {
                    Task { await viewModel.testDNSServers() }
                }
                .disabled(viewModel.isTestingServers)

                Button("Flush DNS Cache") {
                    Task { await viewModel.flushDNS() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isFlushing)
            }

            List {
                if let succeeded = viewModel.flushSucceeded {
                    Section("Result") {
                        HStack(spacing: 8) {
                            Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(succeeded ? .green : .red)
                            Text(viewModel.statusMessage)
                        }
                    }
                }

                Section("When to Flush DNS") {
                    Label("After changing DNS servers (e.g. switching to 1.1.1.1 or 8.8.8.8)", systemImage: "server.rack")
                    Label("When websites fail to load but internet works", systemImage: "globe")
                    Label("After editing /etc/hosts", systemImage: "doc.text")
                    Label("When DNS records were recently updated for a domain", systemImage: "arrow.clockwise")
                }
                .font(.callout)

                if !viewModel.dnsServers.isEmpty {
                    Section("Current DNS Configuration") {
                        ForEach(Array(viewModel.dnsServers.enumerated()), id: \.offset) { _, info in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(info.domain ?? "Default")
                                        .font(.body.bold())
                                    Spacer()
                                    Text(info.resolver)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                ForEach(info.servers, id: \.self) { server in
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 4))
                                            .foregroundStyle(.green)
                                        Text(server)
                                            .font(.callout.monospaced())
                                            .foregroundStyle(.secondary)

                                        if let latency = viewModel.serverLatencies[server] {
                                            Text(latency)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(latency == "timeout" ? .red : .green)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else if viewModel.isLoadingDNS {
                    Section("Current DNS Configuration") {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading DNS configuration...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Suggested DNS Servers") {
                    ForEach(viewModel.dnsPresets, id: \.server) { preset in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.body.bold())
                                Text(preset.server)
                                    .font(.callout.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let latency = viewModel.serverLatencies[preset.server] {
                                Text(latency)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(latency == "timeout" ? .red : .green)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            StatusBar(message: viewModel.lastFlushDate.map { "Last flushed: \(Self.relativeFormatter.localizedString(for: $0, relativeTo: Date()))" } ?? "DNS cache has not been flushed this session", isLoading: false) {
                EmptyView()
            }
        }
        .task {
            await viewModel.loadDNSInfo()
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
