import SwiftUI

/// Shared placeholder layout for the stage-0 tabs; replaced tab by tab in later stages.
struct TabScaffold: View {
    let title: String
    let blurb: String

    var body: some View {
        ZStack {
            Theme.Colors.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(Theme.Fonts.display(34))
                    .foregroundStyle(Theme.Colors.ink)
                BrickDivider()
                Text(blurb)
                    .font(Theme.Fonts.ui(16))
                    .foregroundStyle(Theme.Colors.ink.opacity(0.75))
                Spacer()
            }
            .padding(20)
        }
    }
}
