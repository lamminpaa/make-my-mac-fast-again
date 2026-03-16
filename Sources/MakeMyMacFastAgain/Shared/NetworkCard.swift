import SwiftUI

struct NetworkCard: View {
    let rateIn: Double
    let rateOut: Double

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
                .frame(height: 80)

            VStack(spacing: 8) {
                Text("Network")
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                    Text(ByteFormatter.formatRate(rateIn))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                    Text(ByteFormatter.formatRate(rateOut))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
