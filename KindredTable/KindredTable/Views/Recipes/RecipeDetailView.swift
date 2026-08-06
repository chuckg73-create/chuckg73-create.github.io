import SwiftUI
import UIKit

/// Full recipe view with ingredients, steps, and save-for-later.
struct RecipeDetailView: View {
    var recipe: Recipe
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(GroceryStore.self) private var grocery
    @State private var addedToList = false
    /// Keeps the display awake while cooking (no auto-lock).
    @State private var keepAwake = false
    @State private var showCookMode = false

    var body: some View {
        ZStack {
            KindredBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if !recipe.steps.isEmpty { cookModeButton }
                    if !recipe.whyYoullLikeIt.isEmpty { whyCard }
                    ingredientsCard
                    stepsCard
                    if !recipe.tips.isEmpty { tipsCard }
                    if !recipe.tags.isEmpty { tagRow }
                }
                .padding(20)
            }
        }
        .navigationTitle(recipe.mealType.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: keepAwake) { _, on in
            UIApplication.shared.isIdleTimerDisabled = on
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .fullScreenCover(isPresented: $showCookMode) {
            CookModeView(recipe: recipe)
        }
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
                Label("Serves \(recipe.servings)", systemImage: "person.2.fill")
                Label("\(recipe.totalMinutes) min", systemImage: "clock")
                Label(recipe.difficulty.title, systemImage: "gauge.with.dots.needle.33percent")
            }
            .font(.caption)
            .foregroundStyle(KindredTheme.faint)
            if recipe.prepMinutes > 0 || recipe.cookMinutes > 0 {
                Text("Prep \(recipe.prepMinutes) min · Cook \(recipe.cookMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(KindredTheme.faint)
            }
        }
    }

    private var cookModeButton: some View {
        Button { showCookMode = true } label: {
            Label("Cook Mode — hands-free", systemImage: "hands.sparkles.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: KindredTheme.accent.opacity(0.3), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(label: "Ingredients")
                    Spacer()
                    Text("Serves \(recipe.servings)")
                        .font(.caption).foregroundStyle(KindredTheme.faint)
                }
                ForEach(recipe.ingredients, id: \.self) { ing in
                    ingredientRow(ing)
                }
                if !recipe.needsToBuy.isEmpty {
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
                    .padding(.top, 4)
                }
            }
        }
    }

    private func ingredientRow(_ ing: RecipeIngredient) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: ing.haveIt ? "checkmark.circle.fill" : "cart.fill")
                .font(.caption)
                .foregroundStyle(ing.haveIt ? KindredTheme.mint : KindredTheme.amber)
            if !ing.amount.isEmpty {
                Text(ing.amount)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(KindredTheme.text)
            }
            Text(ing.name)
                .font(.subheadline)
                .foregroundStyle(KindredTheme.subtext)
            Spacer(minLength: 0)
            if !ing.haveIt {
                Text("buy").font(.caption2).foregroundStyle(KindredTheme.amber)
            }
        }
    }

    private var stepsCard: some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeader(label: "Method")
                    Spacer()
                    Button {
                        keepAwake.toggle()
                    } label: {
                        Label(keepAwake ? "Screen on" : "Keep screen on",
                              systemImage: keepAwake ? "sun.max.fill" : "sun.max")
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(keepAwake ? KindredTheme.background : KindredTheme.amber)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(keepAwake ? AnyShapeStyle(KindredTheme.amber) : AnyShapeStyle(KindredTheme.amber.opacity(0.15)),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
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

    private var tipsCard: some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(label: "Tips & hints")
                ForEach(recipe.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption).foregroundStyle(KindredTheme.amber)
                        Text(tip).font(.subheadline)
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
