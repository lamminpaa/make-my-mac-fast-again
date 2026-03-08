import SwiftUI

struct DNSFlushView: View {
    @State private var viewModel = DNSFlushViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "network")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("DNS Cache Flush")
                    .font(.title.bold())

                Text("Flushing the DNS cache can resolve issues with website connectivity, stale DNS records, or after changing DNS servers.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            if viewModel.isFlushing {
                ProgressView("Flushing...")
            } else {
                Button("Flush DNS Cache") {
                    Task { await viewModel.flushDNS() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let succeeded = viewModel.flushSucceeded {
                HStack(spacing: 8) {
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(succeeded ? .green : .red)
                    Text(viewModel.statusMessage)
                        .font(.callout)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            if let date = viewModel.lastFlushDate {
                Text("Last flushed: \(date, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
