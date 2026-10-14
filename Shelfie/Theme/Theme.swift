import SwiftUI

/// "Window seat" design tokens. See CLAUDE.md for the design brief.
enum Theme {
    enum Colors {
        static let cream = Color(hex: 0xF3ECDF)
        static let ink = Color(hex: 0x2A211A)
        static let brick = Color(hex: 0x8E3F2B)
        static let walnut = Color(hex: 0x3B2A1E)
        static let brass = Color(hex: 0xB8945A)
    }

    /// Custom fonts fall back to the system font if a face fails to load.
    enum Fonts {
        static func display(_ size: CGFloat) -> Font { .custom("Libre Caslon Display", size: size) }
        static func title(_ size: CGFloat) -> Font { .custom("Libre Caslon Text", size: size) }
        static func ui(_ size: CGFloat) -> Font { .custom("Libre Franklin", size: size) }
        static func hand(_ size: CGFloat) -> Font { .custom("Kalam", size: size) }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Brick divider used under the Shelf header and between sections.
struct BrickDivider: View {
    var body: some View {
        Rectangle().fill(Theme.Colors.brick).frame(height: 3)
    }
}

/// Brass name-plaque used for swimlane labels.
struct BrassPlaque: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.Fonts.ui(13).weight(.semibold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.Colors.brass, in: RoundedRectangle(cornerRadius: 3))
    }
}
