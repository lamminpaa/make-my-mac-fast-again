import SwiftUI

struct StatusBar<Trailing: View>: View {
    let message: String
    let isLoading: Bool
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            trailing()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
