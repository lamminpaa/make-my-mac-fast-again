import SwiftUI

struct StatusBarPopover: View {
    @Environment(\.appState) private var appState

    private var score: Int { appState?.healthScore ?? 0 }
    private var label: String { appState?.healthScoreLabel ?? "Unknown" }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 50...79:  return .yellow
        default:       return .red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Health score header
            healthScoreSection
            Divider()

            // Stats rows
            VStack(spacing: 10) {
                cpuRow
                memoryRow
                diskRow
                networkRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Action buttons
            actionButtons
        }
        .frame(width: 280)
    }

    // MARK: - Health Score

    private var healthScoreSection: some View {
        HStack(spacing: 12) {
            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(scoreColor)
                Text("Health Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Stat Rows

    private var cpuRow: some View {
        statRow(
            icon: "cpu",
            title: "CPU",
            value: ByteFormatter.formatPercentage(appState?.cpuStats.totalUsage ?? 0)
        )
    }

    private var memoryRow: some View {
        let mem = appState?.memoryStats ?? MemoryStats()
        return statRow(
            icon: "memorychip",
            title: "Memory",
            value: ByteFormatter.formatPercentage(mem.usagePercentage),
            detail: "\(ByteFormatter.format(mem.used)) / \(ByteFormatter.format(mem.total))"
        )
    }

    private var diskRow: some View {
        let disk = appState?.diskStats ?? DiskStats()
        return statRow(
            icon: "internaldrive",
            title: "Disk",
            value: ByteFormatter.formatPercentage(disk.usagePercentage),
            detail: "\(ByteFormatter.format(disk.freeSpace)) free"
        )
    }

    private var networkRow: some View {
        let net = appState?.networkStats ?? NetworkStats()
        return HStack {
            Image(systemName: "network")
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text("Network")
                .font(.callout)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(ByteFormatter.formatRate(net.rateIn))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("\(ByteFormatter.formatRate(net.rateOut))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statRow(
        icon: String,
        title: String,
        value: String,
        detail: String? = nil
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.callout.monospacedDigit())
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Show Main Window") {
                showMainWindow()
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func showMainWindow() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showMainWindow()
        }
    }
}
