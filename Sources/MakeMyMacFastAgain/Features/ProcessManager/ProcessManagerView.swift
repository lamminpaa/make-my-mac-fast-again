import AppKit
import SwiftUI

struct ProcessManagerView: View {
    @State private var viewModel = ProcessManagerViewModel()
    @State private var processToKill: AppProcessInfo?
    @State private var showKillConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Table(viewModel.filteredProcesses, selection: $viewModel.selectedProcessID) {
                TableColumn("PID") { process in
                    Text("\(process.pid)")
                        .monospacedDigit()
                        .font(.caption)
                }
                .width(50)

                TableColumn("Name") { process in
                    Text(process.name)
                        .lineLimit(1)
                }
                .width(min: 150)

                TableColumn("User") { process in
                    Text(process.user)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .width(80)

                TableColumn("Memory") { process in
                    Text(ByteFormatter.format(process.memoryBytes))
                        .monospacedDigit()
                }
                .width(80)

                TableColumn("CPU %") { process in
                    Text(String(format: "%.1f%%", process.cpuPercentage))
                        .monospacedDigit()
                }
                .width(60)

                TableColumn("Status") { process in
                    Text(process.status)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .width(70)

            }
            .contextMenu(forSelectionType: AppProcessInfo.ID.self) { pids in
                if let pid = pids.first,
                   let process = viewModel.processes.first(where: { $0.pid == pid }) {
                    Button("Kill (SIGTERM)") {
                        processToKill = process
                        showKillConfirmation = true
                    }
                    Button("Force Kill (SIGKILL)") {
                        processToKill = process
                        showKillConfirmation = true
                    }
                    Divider()
                    Button("Reveal in Activity Monitor") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                    }
                }
            } primaryAction: { pids in
                // Double-click: no-op
            }

            statusBar
        }
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
        .alert("Kill Process", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Kill (SIGTERM)") {
                if let process = processToKill {
                    Task { await viewModel.killProcess(process) }
                }
            }
            Button("Force Kill (SIGKILL)", role: .destructive) {
                if let process = processToKill {
                    Task { await viewModel.forceKillProcess(process) }
                }
            }
        } message: {
            if let process = processToKill {
                Text("Kill \(process.name) (PID \(process.pid))?\nMemory: \(ByteFormatter.format(process.memoryBytes))")
            }
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Process Manager")
                    .font(.title2.bold())
                Text("View and manage running processes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("Search...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            Picker("Sort by:", selection: $viewModel.sortOrder) {
                ForEach(ProcessManagerViewModel.SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .frame(width: 150)

            Button("Kill Selected") {
                if let pid = viewModel.selectedProcessID,
                   let process = viewModel.processes.first(where: { $0.pid == pid }) {
                    processToKill = process
                    showKillConfirmation = true
                }
            }
            .disabled(viewModel.selectedProcessID == nil)

            Button("Refresh") {
                viewModel.refresh()
            }
        }
        .padding()
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
