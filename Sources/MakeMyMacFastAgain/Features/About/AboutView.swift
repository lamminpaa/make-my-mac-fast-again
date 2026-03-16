import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            appIcon

            Text("Make My Mac Fast Again")
                .font(.title.bold())

            versionInfo

            Divider()
                .padding(.horizontal, 40)

            systemInfo

            Divider()
                .padding(.horizontal, 40)

            credits

            Spacer()
        }
        .frame(width: 360, height: 400)
    }

    private var appIcon: some View {
        Group {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }
        }
    }

    private var versionInfo: some View {
        VStack(spacing: 4) {
            Text("Version \(AppVersion.version)")
                .font(.callout)
            Text("Build \(AppVersion.build) (\(AppVersion.gitHash))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var systemInfo: some View {
        VStack(spacing: 4) {
            Text("macOS \(Foundation.ProcessInfo.processInfo.operatingSystemVersionString)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Swift \(swiftVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var credits: some View {
        VStack(spacing: 4) {
            Text("A native macOS system optimizer")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Built with SwiftUI")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var swiftVersion: String {
        #if swift(>=6.0)
        "6.0+"
        #elseif swift(>=5.10)
        "5.10+"
        #else
        "5.x"
        #endif
    }
}
