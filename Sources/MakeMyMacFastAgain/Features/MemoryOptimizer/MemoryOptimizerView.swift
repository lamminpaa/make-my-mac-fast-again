import SwiftUI

struct MemoryOptimizerView: View {
    @State private var viewModel = MemoryOptimizerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerBar
                memoryGauge
                memoryBreakdown

                if viewModel.showResult {
                    purgeResultCard
                }
            }
            .padding()
        }
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Memory Optimizer")
                    .font(.title2.bold())
                Text("View memory usage and free up inactive memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isPurging {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }

            Button("Purge Memory") {
                Task { await viewModel.purgeMemory() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isPurging)
        }
    }

    private var memoryGauge: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 16)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: min(viewModel.memoryStats.usagePercentage / 100, 1.0))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.memoryStats.usagePercentage)

                VStack(spacing: 4) {
                    Text(ByteFormatter.formatPercentage(viewModel.memoryStats.usagePercentage))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(ByteFormatter.format(viewModel.memoryStats.used)) / \(ByteFormatter.format(viewModel.memoryStats.total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var gaugeColor: Color {
        let pct = viewModel.memoryStats.usagePercentage
        if pct < 60 { return .green }
        else if pct < 80 { return .yellow }
        else { return .red }
    }

    private var memoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.headline)

            memoryBar("Active", viewModel.memoryStats.active, viewModel.memoryStats.total, .blue)
            memoryBar("Wired", viewModel.memoryStats.wired, viewModel.memoryStats.total, .orange)
            memoryBar("Compressed", viewModel.memoryStats.compressed, viewModel.memoryStats.total, .purple)
            memoryBar("Inactive", viewModel.memoryStats.inactive, viewModel.memoryStats.total, .gray)
            memoryBar("Free", viewModel.memoryStats.free, viewModel.memoryStats.total, .green)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func memoryBar(_ label: String, _ value: UInt64, _ total: UInt64, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(ByteFormatter.format(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(value) / CGFloat(total) : 0, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private var purgeResultCard: some View {
        HStack(spacing: 20) {
            VStack {
                Text("Before")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.format(viewModel.memoryBefore))
                    .font(.title3.bold())
            }

            Image(systemName: "arrow.right")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack {
                Text("After")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.format(viewModel.memoryAfter))
                    .font(.title3.bold())
                    .foregroundStyle(.green)
            }

            Spacer()

            VStack {
                Text("Freed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                let freed = viewModel.memoryBefore > viewModel.memoryAfter ? viewModel.memoryBefore - viewModel.memoryAfter : 0
                Text(ByteFormatter.format(freed))
                    .font(.title3.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
