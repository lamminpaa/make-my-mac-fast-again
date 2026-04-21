import SwiftUI

/// Displays 1/5/15-minute Unix load averages alongside the core count.
/// Color reflects the 1-minute load ratio:
/// - green: load per core < 0.7 (idle)
/// - yellow: 0.7-1.5 (busy)
/// - red: >= 1.5 (overloaded)
struct LoadCard: View {
    let loadStats: LoadStats

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Load Average")
                    .font(.headline)
                Text("\(loadStats.activeProcessorCount) cores")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            loadColumn(label: "1m", value: loadStats.oneMinute, emphasized: true)
            loadColumn(label: "5m", value: loadStats.fiveMinutes, emphasized: false)
            loadColumn(label: "15m", value: loadStats.fifteenMinutes, emphasized: false)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func loadColumn(label: String, value: Double, emphasized: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Self.formatLoad(value))
                .font(emphasized ? .title2.monospacedDigit().bold() : .title3.monospacedDigit())
                .foregroundStyle(emphasized ? statusColor : .secondary)
                .contentTransition(.numericText())
        }
        .frame(width: 72, alignment: .trailing)
    }

    private var statusColor: Color {
        let ratio = loadStats.loadRatio
        if ratio < 0.7 { return .green }
        if ratio < 1.5 { return .yellow }
        return .red
    }

    nonisolated static func formatLoad(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
