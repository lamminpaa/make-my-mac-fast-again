import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.load()

    var body: some View {
        Form {
            Section("Monitoring") {
                HStack {
                    Text("Dashboard refresh interval")
                    Spacer()
                    Picker("", selection: $settings.dashboardRefreshInterval) {
                        Text("1 second").tag(1.0 as TimeInterval)
                        Text("2 seconds").tag(2.0 as TimeInterval)
                        Text("5 seconds").tag(5.0 as TimeInterval)
                        Text("10 seconds").tag(10.0 as TimeInterval)
                    }
                    .frame(width: 150)
                }

                HStack {
                    Text("Process manager refresh interval")
                    Spacer()
                    Picker("", selection: $settings.processRefreshInterval) {
                        Text("1 second").tag(1.0 as TimeInterval)
                        Text("3 seconds").tag(3.0 as TimeInterval)
                        Text("5 seconds").tag(5.0 as TimeInterval)
                        Text("10 seconds").tag(10.0 as TimeInterval)
                    }
                    .frame(width: 150)
                }
            }

            Section("Safety") {
                Toggle("Confirm before cleaning caches", isOn: $settings.confirmBeforeCleanup)
                Toggle("Confirm before killing processes", isOn: $settings.confirmBeforeKillProcess)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
        .onChange(of: settings.dashboardRefreshInterval) { _, _ in settings.save() }
        .onChange(of: settings.processRefreshInterval) { _, _ in settings.save() }
        .onChange(of: settings.confirmBeforeCleanup) { _, _ in settings.save() }
        .onChange(of: settings.confirmBeforeKillProcess) { _, _ in settings.save() }
    }
}
