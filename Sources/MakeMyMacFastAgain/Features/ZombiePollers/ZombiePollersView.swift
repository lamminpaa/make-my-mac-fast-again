import AppKit
import SwiftUI

struct ZombiePollersView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = ZombiePollersViewModel()
    @State private var pollerToKill: ZombiePoller?
    @State private var showKillConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(
                title: "Zombie Pollers",
                subtitle: "Orphaned shell loops spawning short-lived children"
            ) {
                EmptyView()
            }

            if viewModel.pollers.isEmpty {
                emptyState
            } else {
                pollerList
            }

            StatusBar(message: viewModel.statusMessage, isLoading: false) {
                EmptyView()
            }
        }
        .task {
            if let appState {
                viewModel.bind(to: appState)
            }
        }
        .onChange(of: viewModel.pollers.count) { _, _ in
            viewModel.refreshStatus()
        }
        .alert(
            "Kill \(pollerToKill?.shell ?? "Process")?",
            isPresented: $showKillConfirmation,
            presenting: pollerToKill
        ) { poller in
            Button("Cancel", role: .cancel) {}
            Button("Kill (SIGTERM)", role: .destructive) {
                Task { await viewModel.kill(poller) }
            }
        } message: { poller in
            Text(
                "Terminate \(poller.shell) (PID \(poller.pid))?\n"
                + "Running for \(ZombiePollerCard.formatUptime(poller.uptimeSeconds)), "
                + "spawning \(String(format: "%.1f", poller.spawnsPerMinute))/min.\n\n"
                + "Command:\n\(poller.command)"
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("No runaway loops detected")
                .font(.title3)
            Text("Long-lived \(Text("sh -c").font(.body.monospaced())) / \(Text("zsh -c").font(.body.monospaced())) processes that spawn children at high frequency show up here. Legitimate shell pipelines are not flagged.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pollerList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                explainer

                ForEach(viewModel.pollers) { poller in
                    pollerRow(poller)
                }
            }
            .padding()
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("These are shell processes running \(Text("while").font(.body.monospaced())) / \(Text("until").font(.body.monospaced())) loops with \(Text("sleep").font(.body.monospaced())) intervals — often left behind by a closed terminal. Activity Monitor shows only the short-lived children, so the parent is usually invisible until now.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func pollerRow(_ poller: ZombiePoller) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "ant.fill")
                    .foregroundStyle(.orange)
                Text(poller.shell)
                    .font(.headline)
                Text("PID \(poller.pid)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if poller.ppid > 0 {
                    Text("← PPID \(poller.ppid)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                metric(label: "Uptime", value: ZombiePollerCard.formatUptime(poller.uptimeSeconds))
                metric(label: "Spawn rate", value: String(format: "%.1f/min", poller.spawnsPerMinute))
            }

            Text(poller.command)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    pollerToKill = poller
                    showKillConfirmation = true
                } label: {
                    Label("Kill", systemImage: "xmark.circle")
                }

                Button {
                    copyCommand(poller.command)
                } label: {
                    Label("Copy command", systemImage: "doc.on.doc")
                }

                Button {
                    viewModel.ignore(poller)
                } label: {
                    Label("Ignore for session", systemImage: "eye.slash")
                }

                Spacer()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.callout.monospacedDigit())
        }
    }

    private func copyCommand(_ command: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(command, forType: .string)
    }
}
