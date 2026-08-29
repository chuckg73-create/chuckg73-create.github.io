import SwiftUI
import UIKit

/// A beautiful, self-contained image card for a recipe — the recipe's photo, its
/// title, family attribution, and memory — so a treasured family recipe can be
/// shared (Messages, Mail, anywhere) even with people who don't have the app.
struct RecipeShareCardView: View {
    let recipe: Recipe
    /// The recipe's photo (cook's own, or generated). Nil falls back to a gradient.
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let photo {
                        Image(uiImage: photo).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(colors: [Color(hex: 0xFF9E33), Color(hex: 0xFF6B47)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .frame(width: 1080, height: 760)
                .clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                    .frame(width: 1080, height: 760)

                VStack(alignment: .leading, spacing: 14) {
                    if !recipe.sourceNote.isEmpty {
                        Text("From \(recipe.sourceNote)")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xFF8A6B))
                    }
                    Text(recipe.title)
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                }
                .padding(56)
            }

            VStack(alignment: .leading, spacing: 22) {
                if !recipe.story.isEmpty {
                    Text("“\(recipe.story)”")
                        .font(.system(size: 36, weight: .regular)).italic()
                        .foregroundStyle(Color(hex: 0xD8DCEA))
                        .lineLimit(3)
                }
                HStack(spacing: 40) {
                    metaItem("clock", "\(recipe.totalMinutes) min")
                    metaItem("person.2.fill", "Serves \(recipe.servings)")
                    if recipe.totalMinutes > 0 { metaItem("flame.fill", recipe.difficulty.title) }
                }
                Divider().overlay(Color.white.opacity(0.12))
                HStack(spacing: 14) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(hex: 0x35D6A0))
                    Text("Made with KindredTable")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("kindredtable.app")
                        .font(.system(size: 26))
                        .foregroundStyle(Color(hex: 0x8C93BD))
                }
            }
            .padding(56)
            .frame(width: 1080, alignment: .leading)
            .background(Color(hex: 0x0A1512))
        }
        .frame(width: 1080)
        .background(Color(hex: 0x0A1512))
    }

    private func metaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(Color(hex: 0x35D6A0))
            Text(text).font(.system(size: 32, weight: .medium)).foregroundStyle(.white)
        }
    }
}

enum RecipeShareCard {
    /// Renders the share card to a PNG image on the main actor.
    @MainActor
    static func render(_ recipe: Recipe, photo: UIImage?) -> UIImage? {
        let renderer = ImageRenderer(content: RecipeShareCardView(recipe: recipe, photo: photo))
        renderer.scale = 1
        return renderer.uiImage
    }
}

/// Minimal UIActivityViewController wrapper for sharing a rendered card image.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
