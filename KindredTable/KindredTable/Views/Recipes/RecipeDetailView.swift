import SwiftUI

/// Full recipe view with ingredients, steps, and save-for-later.
struct RecipeDetailView: View {
    var recipe: Recipe
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(GroceryStore.self) private var grocery
    @State private var addedToList = false

    var body: some View {
        ZStack {
            KindredBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if !recipe.whyYoullLikeIt.isEmpty { whyCard }
                    ingredientsCard
                    stepsCard
                    if !recipe.tags.isEmpty { tagRow }
                }
                .padding(20)
            }
        }
        .navigationTitle(recipe.mealType.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saved.toggle(recipe)
                } label: {
                    Image(systemName: saved.isSaved(recipe) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(saved.isSaved(recipe) ? KindredTheme.amber : KindredTheme.accent)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(recipe.title)
                    .font(.title).fontWeight(.bold)
                Spacer()
                MatchBadge(score: recipe.matchScore)
            }
            Text(recipe.summary)
                .foregroundStyle(KindredTheme.subtext)
            HStack(spacing: 14) {
                Label("\(recipe.cookMinutes) min", systemImage: "clock")
                Label(recipe.difficulty.title, systemImage: "gauge.with.dots.needle.33percent")
                Label(recipe.mealType.title, systemImage: recipe.mealType.systemImage)
            }
            .font(.caption)
            .foregroundStyle(KindredTheme.faint)
        }
    }

    private var whyCard: some View {
        KindredCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "heart.fill").foregroundStyle(KindredTheme.coral)
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(label: "Why you'll like it")
                    Text(recipe.whyYoullLikeIt).font(.subheadline)
                }
            }
        }
    }

    private var ingredientsCard: some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 14) {
                if !recipe.usesOnHand.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(label: "From your pantry")
                        FlowChips(items: recipe.usesOnHand, tint: KindredTheme.mint, icon: "checkmark")
                    }
                }
                if !recipe.needsToBuy.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(label: "You'll need to buy")
                        FlowChips(items: recipe.needsToBuy, tint: KindredTheme.amber, icon: "cart")
                        Button {
                            grocery.addMany(recipe.needsToBuy)
                            withAnimation { addedToList = true }
                        } label: {
                            Label(
                                addedToList ? "Added to grocery list" : "Add \(recipe.needsToBuy.count) to grocery list",
                                systemImage: addedToList ? "checkmark.circle.fill" : "cart.badge.plus"
                            )
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(addedToList ? KindredTheme.mint : KindredTheme.accent)
                        }
                        .disabled(addedToList)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var stepsCard: some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(label: "Method")
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(KindredTheme.brandGradient, in: Circle())
                        Text(step).font(.subheadline)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var tagRow: some View {
        FlowChips(items: recipe.tags, tint: KindredTheme.blue, icon: nil)
    }
}

/// Simple wrapping chip layout.
struct FlowChips: View {
    var items: [String]
    var tint: Color
    var icon: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Chip(text: item, systemImage: icon, tint: tint)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: SampleData.recipes[0])
            .environment(SavedRecipeStore())
            .environment(GroceryStore())
    }
    .preferredColorScheme(.dark)
}
