import SwiftUI

struct HealthScoreGauge: View {
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

    private var gradientColors: [Color] {
        switch score {
        case 80...100: return [.green, .mint]
        case 50...79:  return [.yellow, .orange]
        default:       return [.red, .orange]
        }
    }

    private var progress: Double {
        Double(score) / 100.0
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
                    .frame(width: 120, height: 120)

                // Filled arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: gradientColors),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Score number in center
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                    .contentTransition(.numericText(value: Double(score)))
            }
            .animation(.smooth(duration: 0.6), value: score)

            Text(label)
                .font(.headline)
                .foregroundStyle(scoreColor)

            Text("Health Score")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
