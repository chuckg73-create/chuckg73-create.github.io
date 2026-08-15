import SwiftUI

/// A recipe's hero image. Shows the real photo when the recipe has an
/// `imageURL` (e.g. a web import), otherwise a designed warm placeholder keyed
/// to the dish — so every card looks intentional and appetizing, never blank.
struct RecipeHeroImage: View {
    let recipe: Recipe
    var height: CGFloat = 150
    var glyphSize: CGFloat = 54

    var body: some View {
        ZStack {
            placeholder   // always underneath — shows while a photo loads/fails
            if let url = photoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
    }

    private var photoURL: URL? {
        let s = recipe.imageURL.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        return URL(string: s)
    }

    // MARK: Designed placeholder

    private var placeholder: some View {
        let pair = Self.palette[Self.index(for: recipe.title, mod: Self.palette.count)]
        return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .center) {
                Image(systemName: recipe.mealType.systemImage)
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.28))
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "fork.knife")
                    .font(.system(size: glyphSize * 0.7, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.10))
                    .padding(14)
            }
    }

    /// Warm, appetizing gradient pairs (0xRRGGBB) — on-brand amber/coral/rose.
    private static let palette: [(UInt32, UInt32)] = [
        (0xFF9E33, 0xFF6B47),   // amber → coral
        (0xFF7A3D, 0xE0466B),   // orange → rose
        (0xF9A03F, 0xE8552A),   // honey → burnt orange
        (0xFFB05C, 0xFF5E7E),   // peach → pink
        (0xE8894A, 0xB2456B),   // terracotta → mulberry
        (0xFFC24B, 0xF06543),   // gold → tomato
    ]

    /// Deterministic index from a string (String.hashValue is randomized per run).
    private static func index(for s: String, mod: Int) -> Int {
        guard mod > 0 else { return 0 }
        var h: UInt32 = 5381
        for b in s.utf8 { h = (h &* 33) &+ UInt32(b) }
        return Int(h % UInt32(mod))
    }
}
