import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
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

                    GaugeCard(
                        title: "Network",
                        value: 0,
                        subtitle: ByteFormatter.formatRate(viewModel.networkStats.rateIn),
                        detail: ByteFormatter.formatRate(viewModel.networkStats.rateOut)
                    )
                }

                networkDetailCard

                memoryBreakdownCard
            }
            .padding()
        }
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
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
}
