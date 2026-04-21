import SwiftUI

/// Modal that lists startup items the optimizer is willing to disable and
/// lets the user pick which to apply. Convenience items come pre-checked;
/// unknowns are off by default so the user has to explicitly opt them in.
struct StartupOptimizerSheet: View {
    let candidates: [StartupItem]
    let initialSelection: Set<UUID>
    let onApply: (Set<UUID>) -> Void
    let onCancel: () -> Void

    @State private var selection: Set<UUID> = []

    private var conveniences: [StartupItem] {
        candidates.filter { $0.category == .convenience }
    }
    private var unknowns: [StartupItem] {
        candidates.filter { $0.category == .unknown }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if candidates.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !conveniences.isEmpty {
                            section(
                                title: "Optional helpers",
                                subtitle: "Auto-update agents and convenience helpers. Safe to disable.",
                                items: conveniences
                            )
                        }
                        if !unknowns.isEmpty {
                            section(
                                title: "Not recognised",
                                subtitle: "We don't have these in our allow-list. Only check items you recognise.",
                                items: unknowns
                            )
                        }
                    }
                    .padding()
                }
            }

            Divider()

            footer
        }
        .frame(minWidth: 560, minHeight: 440)
        .onAppear { selection = initialSelection }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Optimize Startup Items")
                .font(.title2.bold())
            Text("Apple system services and recognised safety-critical tools are hidden — they're never proposed for disabling.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Nothing to optimize")
                .font(.headline)
            Text("All currently enabled startup items are Apple-system or safety-critical.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func section(title: String, subtitle: String, items: [StartupItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { item in
                    candidateRow(item)
                }
            }
        }
    }

    private func candidateRow(_ item: StartupItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(
                get: { selection.contains(item.id) },
                set: { isOn in
                    if isOn { selection.insert(item.id) } else { selection.remove(item.id) }
                }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.body.bold())
                    categoryBadge(item.category)
                }
                Text(item.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .help(item.category.explanation)
    }

    private func categoryBadge(_ category: StartupCategory) -> some View {
        Text(category.shortLabel)
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(badgeColor(category).opacity(0.15))
            .foregroundStyle(badgeColor(category))
            .clipShape(Capsule())
    }

    private func badgeColor(_ category: StartupCategory) -> Color {
        switch category {
        case .appleSystem: return .gray
        case .safetyCritical: return .red
        case .convenience: return .blue
        case .unknown: return .orange
        }
    }

    private var footer: some View {
        HStack {
            Text("\(selection.count) of \(candidates.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)

            Button("Disable Selected") { onApply(selection) }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
        }
        .padding()
    }
}
