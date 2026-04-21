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
                        if AppSettings.load().confirmBeforeKillProcess {
                            processToKill = process
                            showKillConfirmation = true
                        } else {
                            Task { await viewModel.killProcess(process) }
                        }
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

                TableColumn("Launched by") { process in
                    Text(parentLabel(for: process))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .help(ancestorTooltip(for: process))
                }
                .width(min: 120, ideal: 160)

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
                        if AppSettings.load().confirmBeforeKillProcess {
                            processToKill = process
                            showKillConfirmation = true
                        } else {
                            Task { await viewModel.killProcess(process) }
                        }
                    }
                    .disabled(process.isProtected)

                    Button("Force Kill (SIGKILL)") {
                        if AppSettings.load().confirmBeforeKillProcess {
                            processToKill = process
                            showKillConfirmation = true
                        } else {
                            Task { await viewModel.forceKillProcess(process) }
                        }
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

            if let pid = viewModel.selectedProcessID {
                ancestorDetailStrip(for: pid)
            }

            StatusBar(message: viewModel.statusMessage, isLoading: false) {
                EmptyView()
            }
        }
        .task {
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

    private func parentLabel(for process: AppProcessInfo) -> String {
        let ppid = process.ppid
        if ppid <= 0 { return "—" }
        if ppid == 1 { return "launchd (1)" }
        if let parent = viewModel.processesByPID[ppid] {
            return "\(parent.name) (\(ppid))"
        }
        return "pid \(ppid) (gone)"
    }

    private func ancestorTooltip(for process: AppProcessInfo) -> String {
        let chain = viewModel.ancestors(of: process.pid)
        if chain.isEmpty {
            return process.ppid <= 1 ? "No parent process" : "Parent pid \(process.ppid) no longer exists"
        }
        return chain
            .map { ancestor in
                let command = ancestor.commandLine.isEmpty ? ancestor.name : ancestor.commandLine
                return "\(ancestor.name) (\(ancestor.pid)) — \(command)"
            }
            .joined(separator: "\n")
    }

    @ViewBuilder
    private func ancestorDetailStrip(for pid: pid_t) -> some View {
        // If the selected process exited between refreshes, suppress the strip
        // entirely rather than showing an orphaned ancestor list.
        if let selected = viewModel.processesByPID[pid] {
            let chain = Array(viewModel.ancestors(of: pid).reversed())

            VStack(alignment: .leading, spacing: 4) {
                Text("Parent chain")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(chain.enumerated()), id: \.element.pid) { index, ancestor in
                    ancestorRow(ancestor, indent: index, isSelected: false)
                }

                ancestorRow(selected, indent: chain.count, isSelected: true)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .top)
        }
    }

    @ViewBuilder
    private func ancestorRow(_ process: AppProcessInfo, indent: Int, isSelected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if indent > 0 {
                Text(String(repeating: "  ", count: indent) + "↳")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Text(process.name)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
            Text("(\(process.pid))")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            if !process.commandLine.isEmpty {
                Text(process.commandLine)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
    }

}
