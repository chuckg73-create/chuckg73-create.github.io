import SwiftUI

/// Central design tokens for KindredTable.
///
/// Colors are adaptive: each token carries both a dark and light appearance.
/// The dark palette matches the original forest-green canvas. The light palette
/// uses a pale mint-white canvas with darker, contrast-compliant tints.
enum KindredTheme {

    // MARK: Core palette

    static let background  = Color.adaptive(light: 0xF4FAF6, dark: 0x0A1512)
    static let surface     = Color.adaptive(light: 0xE8F5EC, dark: 0x122019)
    static let card        = Color.adaptive(light: 0xFFFFFF, dark: 0x162A20)
    static let cardElevated = Color.adaptive(light: 0xF0F8F3, dark: 0x1F3529)

    // accent: bright emerald in dark; darker emerald in light for WCAG AA on white
    static let accent  = Color.adaptive(light: 0x059669, dark: 0x35D6A0)
    static let blue    = Color.adaptive(light: 0x1D4ED8, dark: 0x3B82F6)
    static let amber   = Color.adaptive(light: 0xB45309, dark: 0xFF9E33)
    static let coral   = Color.adaptive(light: 0xC2410C, dark: 0xFF6B47)
    static let mint    = Color.adaptive(light: 0x047857, dark: 0x34D399)
    static let violet  = Color.adaptive(light: 0x5B21B6, dark: 0x7866FA)

    static let text    = Color.adaptive(light: 0x0F1B16, dark: 0xFFFFFF)
    static let subtext = Color.adaptive(light: 0x374151, dark: 0xB5BAD4)
    static let faint   = Color.adaptive(light: 0x6B7280, dark: 0x8C93BD)

    static let hairline = Color.adaptiveHairline

    // MARK: Gradients

    static var brandGradient: LinearGradient {
        // Deep emerald → teal — dark enough that white button text clears WCAG AA.
        // Same hex values work in both light and dark (they're already dark enough).
        LinearGradient(
            colors: [Color(hex: 0x059669), Color(hex: 0x0D9488)],
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
            colors: [accent.opacity(0.15), background],
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

    /// Create a color that automatically selects a light or dark hex based on
    /// the current color scheme — no asset catalog required.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255
            let g = CGFloat((hex >> 8)  & 0xFF) / 255
            let b = CGFloat(hex & 0xFF)          / 255
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
    }

    /// Hairline separator: near-invisible white tint in dark mode, subtle black
    /// tint in light mode — keeps card borders readable on both canvases.
    static let adaptiveHairline = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.07)
            : UIColor.black.withAlphaComponent(0.09)
    })
}

// MARK: - Reusable surfaces

/// A rounded, hairline-bordered card matching the KindredTable surface style.
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
