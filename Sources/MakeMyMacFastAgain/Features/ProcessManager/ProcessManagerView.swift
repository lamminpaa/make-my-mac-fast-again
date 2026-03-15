import AppKit
import SwiftUI

struct ProcessManagerView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = ProcessManagerViewModel()
    @State private var processToKill: AppProcessInfo?
    @State private var showKillConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            FeatureHeader(title: "Process Manager", subtitle: "View and manage running processes") {
                Button("Kill Selected") {
                    if let pid = viewModel.selectedProcessID,
                       let process = viewModel.processes.first(where: { $0.pid == pid }),
                       !process.isProtected {
                        processToKill = process
                        showKillConfirmation = true
                    }
                }
                .disabled(viewModel.selectedProcessID == nil || {
                    guard let pid = viewModel.selectedProcessID else { return true }
                    return viewModel.processes.first(where: { $0.pid == pid })?.isProtected == true
                }())

                Button("Refresh") {
                    viewModel.refresh()
                }
            }

            HStack(spacing: 12) {
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    ForEach(ProcessManagerViewModel.ProcessFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Spacer()

                Picker("Sort by:", selection: $viewModel.sortOrder) {
                    ForEach(ProcessManagerViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

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
                    Text(process.cpuPercentage == 0 ? "-" : String(format: "%.1f%%", process.cpuPercentage))
                        .monospacedDigit()
                        .foregroundStyle(process.cpuPercentage == 0 ? .tertiary : .primary)
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
                    .disabled(process.isProtected)

                    Button("Force Kill (SIGKILL)") {
                        processToKill = process
                        showKillConfirmation = true
                    }
                    .disabled(process.isProtected)

                    Divider()
                    Button("Reveal in Activity Monitor") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                    }
                }
            } primaryAction: { pids in
                // Double-click: no-op
            }

            StatusBar(message: viewModel.statusMessage, isLoading: false) {
                EmptyView()
            }
        }
        .onAppear {
            if let appState {
                viewModel.bind(to: appState)
            }
            viewModel.startMonitoring()
        }
        .onDisappear { viewModel.stopMonitoring() }
        .alert("Kill \(processToKill?.name ?? "Process")?", isPresented: $showKillConfirmation) {
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

}
