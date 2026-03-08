import SwiftUI

struct GaugeCard: View {
    let title: String
    let value: Double
    let subtitle: String
    let detail: String

    private var gaugeColor: Color {
        if value < 60 {
            return .green
        } else if value < 80 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: value)

                Text(ByteFormatter.formatPercentage(value))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(gaugeColor)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
