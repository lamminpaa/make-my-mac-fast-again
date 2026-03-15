import SwiftUI

struct DashboardView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            if viewModel.hasInitialData {
                dashboardContent
                    .transition(.opacity)
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .padding()
            }
        }
        .animation(.easeIn(duration: 0.3), value: viewModel.hasInitialData)
        .onAppear {
            if let appState {
                viewModel.bind(to: appState)
            }
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 20) {
            systemInfoBar

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                GaugeCard(
                    title: "CPU",
                    value: viewModel.cpuStats.totalUsage,
                    subtitle: "User: \(ByteFormatter.formatPercentage(viewModel.cpuStats.userPercentage))",
                    detail: "System: \(ByteFormatter.formatPercentage(viewModel.cpuStats.systemPercentage))"
                )

                GaugeCard(
                    title: "Memory",
                    value: viewModel.memoryStats.usagePercentage,
                    subtitle: "\(ByteFormatter.format(viewModel.memoryStats.used)) used",
                    detail: "of \(ByteFormatter.format(viewModel.memoryStats.total))"
                )

                GaugeCard(
                    title: "Disk",
                    value: viewModel.diskStats.usagePercentage,
                    subtitle: "\(ByteFormatter.format(viewModel.diskStats.freeSpace)) free",
                    detail: "of \(ByteFormatter.format(viewModel.diskStats.totalSpace))"
                )

                NetworkCard(
                    rateIn: viewModel.networkStats.rateIn,
                    rateOut: viewModel.networkStats.rateOut
                )
            }

            sparklineSection

            networkDetailCard

            memoryBreakdownCard

            topProcessesCard
        }
        .padding()
    }

    private var systemInfoBar: some View {
        HStack(spacing: 24) {
            Label(viewModel.systemName, systemImage: "desktopcomputer")
            Label(viewModel.macOSVersion, systemImage: "info.circle")
            Label("Uptime: \(viewModel.uptime)", systemImage: "clock")
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var networkDetailCard: some View {
        HStack(spacing: 40) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Download")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.formatRate(viewModel.networkStats.rateIn))
                    .font(.title3.bold())
                Text("Total: \(ByteFormatter.format(viewModel.networkStats.bytesIn))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Upload")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.formatRate(viewModel.networkStats.rateOut))
                    .font(.title3.bold())
                Text("Total: \(ByteFormatter.format(viewModel.networkStats.bytesOut))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var memoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Breakdown")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                memoryRow("Active", viewModel.memoryStats.active, .blue)
                memoryRow("Wired", viewModel.memoryStats.wired, .orange)
                memoryRow("Compressed", viewModel.memoryStats.compressed, .purple)
                memoryRow("Inactive", viewModel.memoryStats.inactive, .gray)
                memoryRow("Free", viewModel.memoryStats.free, .green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var topProcessesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes by Memory")
                .font(.headline)

            ForEach(viewModel.topProcesses) { process in
                HStack {
                    Text(process.name)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer()
                    Text(ByteFormatter.format(process.memoryBytes))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.topProcesses.isEmpty {
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func memoryRow(_ label: String, _ bytes: UInt64, _ color: Color) -> some View {
        GridRow {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .frame(width: 100, alignment: .leading)
            Text(ByteFormatter.format(bytes))
                .foregroundStyle(.secondary)
        }
    }

    private var sparklineSection: some View {
        HStack(spacing: 16) {
            SparklineCard(
                title: "CPU History (60s)",
                samples: viewModel.cpuHistory,
                color: .blue
            )
            SparklineCard(
                title: "Memory History (60s)",
                samples: viewModel.memoryHistory,
                color: .orange
            )
        }
    }
}

private struct SparklineCard: View {
    let title: String
    let samples: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            SparklineChart(samples: samples, color: color)
                .frame(width: 200, height: 40)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SparklineChart: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            let maxSamples = 30
            let barWidth = size.width / CGFloat(maxSamples)
            let maxValue = max(samples.max() ?? 100, 1)

            for (index, value) in samples.enumerated() {
                let barHeight = CGFloat(value / maxValue) * size.height
                let x = CGFloat(index) * barWidth
                let rect = CGRect(
                    x: x,
                    y: size.height - barHeight,
                    width: max(barWidth - 1, 1),
                    height: barHeight
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1),
                    with: .color(color.opacity(0.7))
                )
            }
        }
    }
}
