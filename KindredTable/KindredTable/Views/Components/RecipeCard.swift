import SwiftUI

/// Compact recipe card used in the feed and saved list.
struct RecipeCard: View {
    var recipe: Recipe
    var isSaved: Bool
    var onSave: () -> Void

    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(TasteFeedbackStore.self) private var feedback

    /// Grounded "why this matched you" line (nil for imported / no concrete match).
    private var matchReason: String? {
        MatchReason.sentence(for: recipe,
                             profile: household.effectiveProfile(you: profileStore.profile),
                             lovedTags: feedback.lovedTags)
    }

    var body: some View {
        VStack(spacing: 0) {
            RecipeHeroImage(recipe: recipe, height: 148)
            VStack(alignment: .leading, spacing: 12) {
                header
                Text(recipe.summary)
                    .font(.subheadline)
                    .foregroundStyle(KindredTheme.subtext)
                    .lineLimit(2)

                if let matchReason {
                    Label {
                        Text(matchReason)
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(KindredTheme.text)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(KindredTheme.accent)
                    }
                    .accessibilityLabel("Why this matched you: \(matchReason)")
                }

                metaRow

                if !recipe.usesOnHand.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(recipe.usesOnHand.prefix(6), id: \.self) { item in
                                Chip(text: item, systemImage: "checkmark", tint: KindredTheme.mint)
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .trailingChipFade()
                    .accessibilityLabel("On hand: \(recipe.usesOnHand.prefix(6).joined(separator: ", "))")
                }
            }
            .padding(16)
        }
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                .stroke(KindredTheme.hairline, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Chip(text: recipe.mealType.title, systemImage: recipe.mealType.systemImage, tint: KindredTheme.blue)
                Text(recipe.title)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(KindredTheme.text)
            }
            Spacer()
            VStack(spacing: 8) {
                MatchBadge(score: recipe.matchScore)
                Button(action: onSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(isSaved ? KindredTheme.amber : KindredTheme.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Saved" : "Save recipe")
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 14) {
            Label("\(recipe.totalMinutes) min", systemImage: "clock")
            Label("Serves \(recipe.servings)", systemImage: "person.2.fill")
            if !recipe.needsToBuy.isEmpty {
                Label("+\(recipe.needsToBuy.count) to buy", systemImage: "cart")
            }
        }
        .font(.caption)
        .foregroundStyle(KindredTheme.faint)
    }
}

#Preview {
    ZStack {
        KindredBackground()
        RecipeCard(recipe: SampleData.recipes[0], isSaved: false, onSave: {})
            .padding()
    }
    .preferredColorScheme(.dark)
    .environment(ProfileStore(seed: nil))
    .environment(HouseholdStore())
    .environment(TasteFeedbackStore())
}
