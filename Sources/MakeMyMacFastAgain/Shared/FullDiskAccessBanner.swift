import SwiftUI
import AppKit

struct FullDiskAccessBanner: View {
    @State private var hasFDA = true
    @State private var dismissed = false

    var body: some View {
        Group {
            if !hasFDA && !dismissed {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Disk Access Required")
                            .font(.callout.bold())
                        Text("Some features need Full Disk Access to scan browser data and system caches.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Open Settings") {
                        let urlString: String
                        if #available(macOS 13, *) {
                            urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
                        } else {
                            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
                        }
                        if let url = URL(string: urlString) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        withAnimation { dismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .onAppear {
            hasFDA = PermissionChecker.hasFullDiskAccess()
        }
    }
}
