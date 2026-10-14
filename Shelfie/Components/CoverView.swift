import SwiftUI

/// A book cover at 2:3. Covers are the hero, so this stays plain: image, soft shadow.
/// Falls back to a walnut spine-coloured tile with the title when there is no image.
struct CoverView: View {
    let url: URL?
    let title: String

    var body: some View {
        placeholder
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            .accessibilityLabel(Text("Cover of \(title)"))
    }

    private var placeholder: some View {
        ZStack {
            Theme.Colors.walnut
            Text(title)
                .font(Theme.Fonts.title(13))
                .foregroundStyle(Theme.Colors.cream)
                .multilineTextAlignment(.center)
                .padding(8)
        }
    }
}
