import SwiftUI

/// The daily meal suggestions feed. Generates recipes from the current pantry +
/// taste profile via the Gemini service, with save-for-later on each card.
struct RecipeFeedView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(HouseholdStore.self) private var household

    @State private var model = RecipeFeedModel()
    /// Meal-type filter. nil = show all types.
    @State private var selectedMealType: MealType?
    @State private var showHousehold = false
    @State private var showCrave = false

    /// The profile Gemini cooks for: you blended with everyone at the table.
    private var effectiveProfile: TasteProfile {
        household.effectiveProfile(you: profileStore.profile)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                content
            }
            .navigationTitle("Today's ideas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoading || pantry.isEmpty)
                    .accessibilityLabel("Refresh ideas")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHousehold = true } label: {
                        Image(systemName: "person.2.fill")
                    }
                    .accessibilityLabel("Cooking together")
                }
                ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showCrave = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Cook a craving")
                }
            }
            .task {
                await model.loadIfNeeded(ingredients: pantry.ingredients, profile: effectiveProfile)
            }
            .onChange(of: household.signature(you: profileStore.profile)) {
                guard !pantry.isEmpty else { return }
                Task { await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile) }
            }
            .sheet(isPresented: $showHousehold) { HouseholdView() }
            .sheet(isPresented: $showCrave) { CraveSearchView() }
        }
    }

    @ViewBuilder private var content: some View {
        if pantry.isEmpty {
            EmptyState(
                systemImage: "sparkles",
                title: "Add ingredients first",
                message: "Once your pantry has a few items, Kindred Kitchen will suggest meals you can make right now."
            )
        } else {
            switch model.phase {
            case .idle, .loading:
                loadingState
            case .failed(let message):
                EmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't load ideas",
                    message: message,
                    actionTitle: "Try again",
                    action: { Task { await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile) } }
                )
            case .loaded(let recipes):
                feed(recipes)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text("Matching recipes to your pantry…")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func feed(_ recipes: [Recipe]) -> some View {
        // Only offer chips for meal types actually present, so a tap never lands
        // on an empty list. A stale selection (type no longer present) falls
        // back to "All".
        let present = MealType.allCases.filter { type in recipes.contains { $0.mealType == type } }
        let effective = (selectedMealType.map(present.contains) ?? false) ? selectedMealType : nil
        let shown = effective == nil ? recipes : recipes.filter { $0.mealType == effective }

        return VStack(spacing: 0) {
            cookingForBar
            mealTypeSelector(present: present, effective: effective)
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.usingSamples { sampleBanner }
                    ForEach(shown) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeCard(
                                recipe: recipe,
                                isSaved: saved.isSaved(recipe),
                                onSave: { saved.toggle(recipe) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .refreshable {
                await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile)
            }
        }
    }

    /// Tappable "Cooking for: You + Leslie" bar — opens the sharing hub.
    private var cookingForBar: some View {
        Button { showHousehold = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill").font(.caption).foregroundStyle(KindredTheme.accent)
                Text("Cooking for").font(.subheadline).foregroundStyle(KindredTheme.subtext)
                Text(household.cookingForSummary()).font(.subheadline.weight(.semibold))
                    .foregroundStyle(KindredTheme.text)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(KindredTheme.faint)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    /// Pinned horizontal meal-type filter so a breakfast (or any type) is one
    /// tap away instead of a scroll.
    private func mealTypeSelector(present: [MealType], effective: MealType?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                typeChip(title: "All", icon: "square.grid.2x2",
                         isSelected: effective == nil) { selectedMealType = nil }
                ForEach(present) { type in
                    typeChip(title: type.title, icon: type.systemImage,
                             isSelected: effective == type) {
                        selectedMealType = (effective == type ? nil : type)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func typeChip(title: String, icon: String, isSelected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : KindredTheme.subtext)
            .background(
                isSelected ? AnyShapeStyle(KindredTheme.brandGradient)
                           : AnyShapeStyle(KindredTheme.card),
                in: Capsule()
            )
            .overlay(Capsule().stroke(isSelected ? Color.clear : KindredTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private var sampleBanner: some View {
        Label(
            "Showing sample ideas — add a Gemini API key to get suggestions tailored to your exact pantry.",
            systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(KindredTheme.amber)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KindredTheme.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    RecipeFeedView()
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(ProfileStore(seed: .starter))
        .environment(SavedRecipeStore())
        .environment(HouseholdStore())
        .preferredColorScheme(.dark)
}
