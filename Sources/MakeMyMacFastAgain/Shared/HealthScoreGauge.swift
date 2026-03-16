import SwiftUI

struct HealthScoreGauge: View {
    @Environment(\.appState) private var appState
    @State private var showBreakdown = false

    private var score: Int { appState?.healthScore ?? 0 }
    private var label: String { appState?.healthScoreLabel ?? "Unknown" }
    private var breakdown: HealthScoreBreakdown? { appState?.healthScoreBreakdown }

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

            Button {
                showBreakdown.toggle()
            } label: {
                Text("Health Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showBreakdown, arrowEdge: .bottom) {
                breakdownPopover
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var breakdownPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Breakdown")
                .font(.headline)

            if let b = breakdown {
                breakdownRow("Disk", score: b.diskScore, weight: "30%", color: .blue)
                breakdownRow("Memory", score: b.memoryScore, weight: "25%", color: .orange)
                breakdownRow("Startup Items", score: b.startupScore, weight: "20%", color: .purple)
                breakdownRow("Caches", score: b.cacheScore, weight: "15%", color: .cyan)
                breakdownRow("Zombies", score: b.zombieScore, weight: "10%", color: .gray)

                Divider()

                HStack {
                    Text("Weighted Total")
                        .font(.callout.bold())
                    Spacer()
                    Text("\(score)/100")
                        .font(.callout.bold().monospacedDigit())
                }
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func breakdownRow(_ title: String, score: Double, weight: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.callout)
                .frame(width: 90, alignment: .leading)

            ProgressView(value: score, total: 100)
                .tint(scoreBarColor(score))
                .frame(width: 60)

            Text("\(Int(score.rounded()))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            Text(weight)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func scoreBarColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 50..<80:  return .yellow
        default:       return .red
        }
    }
}
