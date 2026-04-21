import SwiftUI

/// Compact Dashboard card summarizing detected runaway shell loops. Hidden
/// entirely when none are detected so the Dashboard stays clean on healthy
/// systems. Tapping the "View all" button navigates to the full feature view.
struct ZombiePollerCard: View {
    let pollers: [ZombiePoller]
    let onViewAll: () -> Void

    private static let maxRows = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "ant.fill")
                    .foregroundStyle(.orange)
                Text("Zombie Pollers")
                    .font(.headline)
                Text("\(pollers.count) detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("View all", action: onViewAll)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            Text("Orphaned shell loops spawning short-lived children — usually the real cause of sustained high load.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            ForEach(pollers.prefix(Self.maxRows)) { poller in
                pollerRow(poller)
                if poller.id != pollers.prefix(Self.maxRows).last?.id {
                    Divider().opacity(0.4)
                }
            }

            if pollers.count > Self.maxRows {
                Text("+\(pollers.count - Self.maxRows) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func pollerRow(_ poller: ZombiePoller) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(poller.shell)
                        .font(.callout.bold())
                    Text("PID \(poller.pid)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(poller.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.formatUptime(poller.uptimeSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
                Text("\(String(format: "%.1f", poller.spawnsPerMinute))/min")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    nonisolated static func formatUptime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
