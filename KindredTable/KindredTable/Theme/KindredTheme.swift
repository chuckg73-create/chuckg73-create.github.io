import SwiftUI

/// Central design tokens for KindredTable.
///
/// The palette is lifted from the KindredCompass brand so the two apps read as
/// members of the same family — deep indigo canvas, violet accent, warm amber
/// and coral highlights.
enum KindredTheme {

    // MARK: Core palette

    static let background = Color(hex: 0x080D21)
    static let surface = Color(hex: 0x111833)
    static let card = Color(hex: 0x171E38)
    static let cardElevated = Color(hex: 0x1E2745)

    static let accent = Color(hex: 0x7866FA)   // violet
    static let blue = Color(hex: 0x3B82F6)
    static let amber = Color(hex: 0xFF9E33)
    static let coral = Color(hex: 0xFF6B47)
    static let mint = Color(hex: 0x34D399)

    static let text = Color(hex: 0xFFFFFF)
    static let subtext = Color(hex: 0xB5BAD4)
    static let faint = Color(hex: 0x6B7299)

    static let hairline = Color.white.opacity(0.07)

    // MARK: Gradients

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var warmGradient: LinearGradient {
        LinearGradient(
            colors: [amber, coral],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var canvasGradient: RadialGradient {
        RadialGradient(
            colors: [accent.opacity(0.18), background],
            center: .top,
            startRadius: 0,
            endRadius: 520
        )
    }

    // MARK: Metrics

    static let corner: CGFloat = 22
    static let cardCorner: CGFloat = 26
}

// MARK: - Color helpers

extension Color {
    /// Create a color from a 0xRRGGBB integer literal.
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Reusable surfaces

/// A rounded, hairline-bordered card matching the KindredCompass surface style.
struct KindredCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                    .stroke(KindredTheme.hairline, lineWidth: 1)
            )
    }
}

/// Full-screen brand canvas used behind every tab.
struct KindredBackground: View {
    var body: some View {
        KindredTheme.background
            .overlay(KindredTheme.canvasGradient.opacity(0.9))
            .ignoresSafeArea()
    }
}
