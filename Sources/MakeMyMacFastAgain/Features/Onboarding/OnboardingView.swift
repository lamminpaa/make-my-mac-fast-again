import SwiftUI
import AppKit

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                permissionsPage.tag(1)
                featuresPage.tag(2)
            }
            .tabViewStyle(.automatic)

            navigation
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            Text("Welcome to Make My Mac Fast Again")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Version \(AppVersion.version)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("A native macOS system optimizer built with SwiftUI.\nScan caches, manage processes, and keep your Mac running smoothly.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Page 2: Permissions

    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Full Disk Access")
                .font(.title2.bold())

            Text("Some features need Full Disk Access to scan browser data and system caches. You can grant this permission now or later.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            fdaStatus

            Button("Open System Settings") {
                openPrivacySettings()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    private var fdaStatus: some View {
        HStack(spacing: 8) {
            let hasFDA = PermissionChecker.hasFullDiskAccess()
            Image(systemName: hasFDA ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(hasFDA ? .green : .orange)
            Text(hasFDA ? "Full Disk Access is enabled" : "Full Disk Access is not enabled")
                .font(.callout)
                .foregroundStyle(hasFDA ? .green : .orange)
        }
        .padding(.vertical, 4)
    }

    private func openPrivacySettings() {
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

    // MARK: - Page 3: Features

    private var featuresPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("What You Can Do")
                .font(.title2.bold())

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(NavigationItem.allCases, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.systemImage)
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        Text(item.rawValue)
                            .font(.callout)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Navigation

    private var navigation: some View {
        HStack {
            if currentPage > 0 {
                Button("Back") {
                    withAnimation { currentPage -= 1 }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            pageIndicator

            Spacer()

            if currentPage < 2 {
                Button("Next") {
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.bar)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func completeOnboarding() {
        var settings = AppSettings.load()
        settings.hasCompletedOnboarding = true
        settings.onboardingCompletedVersion = AppVersion.version
        settings.save()
        isPresented = false
    }
}
