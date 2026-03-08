import SwiftUI

struct FeatureHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            actions()
        }
        .padding()
    }
}
