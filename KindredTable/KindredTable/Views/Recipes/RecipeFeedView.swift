import SwiftUI

/// The daily meal suggestions feed. Generates recipes from the current pantry +
/// taste profile via the Gemini service, with save-for-later on each card.
struct RecipeFeedView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(HouseholdStore.self) private var household
    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(TasteFeedbackStore.self) private var feedback
    @Environment(TastePreferenceStore.self) private var preferences
    @Environment(StaplesStore.self) private var staples
    @Environment(RecentSuggestionsStore.self) private var recent

    @State private var model = RecipeFeedModel()
    /// Meal-type filter. nil = show all types.
    @State private var selectedMealType: MealType?
    @State private var showHousehold = false
    @State private var showCrave = false
    @State private var showPlan = false
    /// Filter to recipes that need nothing bought.
    @State private var onHandOnly = false
    /// Recipe just saved — offer to add its missing ingredients to grocery list.
    @State private var groceryCandidate: Recipe?

    /// The profile Gemini cooks for: you blended with everyone at the table.
    private var effectiveProfile: TasteProfile {
        household.effectiveProfile(you: profileStore.profile)
    }

    /// What the cook has taught the engine — dishes they've rated plus their
    /// hand-tuned more/less-like-this steering — folded into one prompt block.
    private var tasteSignals: String? {
        let combined = [feedback.promptSummary(), preferences.promptLine(), staples.promptLine(), recent.avoidBlock()]
            .compactMap { $0 }
            .joined(separator: "\n")
        return combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : combined
    }

    /// A one-off signals string that pushes hard for novelty (the "Surprise me" tap).
    private var surpriseSignals: String? {
        [tasteSignals, "SURPRISE ME — deliberately go beyond this cook's usual picks: explore a different cuisine, protein or technique they don't often get, while still respecting their taste and hard dietary rules."]
            .compactMap { $0 }
            .joined(separator: "\n")
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
                        Task { await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile, servings: household.servings, special: household.specialOccasion, tasteFeedback: tasteSignals, useUpItems: pantry.useUpNames()) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoading || pantry.isEmpty)
                    .accessibilityLabel("Refresh ideas")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile, servings: household.servings, special: household.specialOccasion, tasteFeedback: surpriseSignals, useUpItems: pantry.useUpNames()) }
                    } label: {
                        Image(systemName: "dice.fill")
                    }
                    .disabled(model.isLoading || pantry.isEmpty)
                    .accessibilityLabel("Surprise me")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPlan = true } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Meal plan")
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
                    .accessibilityLabel("Make a meal")
                }
            }
            .task {
                model.recentStore = recent
                await model.loadIfNeeded(ingredients: pantry.ingredients, profile: effectiveProfile, servings: household.servings, special: household.specialOccasion, tasteFeedback: tasteSignals, useUpItems: pantry.useUpNames())
            }
            .onChange(of: household.signature(you: profileStore.profile)) {
                guard !pantry.isEmpty else { return }
                Task { await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile, servings: household.servings, special: household.specialOccasion, tasteFeedback: tasteSignals, useUpItems: pantry.useUpNames()) }
            }
            .sheet(isPresented: $showHousehold) { HouseholdView() }
            .sheet(isPresented: $showCrave) { CraveSearchView() }
            .sheet(isPresented: $showPlan) { MealPlanView() }
            .sheet(item: $groceryCandidate) { recipe in
                GroceryAddSheet(recipe: recipe)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if pantry.isEmpty {
            EmptyState(
                systemImage: "sparkles",
                title: "Add ingredients first",
                message: "Once your pantry has a few items, KindredTable will suggest meals you can make right now."
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
                    action: { Task { await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile, servings: household.servings, special: household.specialOccasion, tasteFeedback: tasteSignals, useUpItems: pantry.useUpNames()) } }
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
        // A recipe needs shopping only if something beyond the cook's staples is missing.
        let needsShopping: (Recipe) -> Bool = { r in r.needsToBuy.contains { !staples.covers($0) } }
        let hasOnHandOnly = recipes.contains { !needsShopping($0) }
        var shown = effective == nil ? recipes : recipes.filter { $0.mealType == effective }
        if onHandOnly { shown = shown.filter { !needsShopping($0) } }

        return VStack(spacing: 0) {
            cookingForBar
            servesStepper
            if household.servings <= 2 { specialToggle }
            mealTypeSelector(present: present, effective: effective, hasOnHandOnly: hasOnHandOnly)
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
                                onSave: {
                                    let wasSaved = saved.isSaved(recipe)
                                    saved.toggle(recipe)
                                    if !wasSaved && !recipe.needsToBuy.isEmpty {
                                        groceryCandidate = recipe
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .refreshable {
                await model.refresh(ingredients: pantry.ingredients, profile: effectiveProfile, servings: household.servings, special: household.specialOccasion, tasteFeedback: tasteSignals, useUpItems: pantry.useUpNames())
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

    /// Quick "how many are eating" control — the fast path from 2 (you + Leslie)
    /// to 4 (boys home) without opening a sheet. Recipes rescale on change.
    private var servesStepper: some View {
        @Bindable var household = household
        return HStack(spacing: 10) {
            Image(systemName: "fork.knife").font(.caption).foregroundStyle(KindredTheme.amber)
            Text("Serves").font(.subheadline).foregroundStyle(KindredTheme.subtext)
            HStack(spacing: 14) {
                stepButton(system: "minus") { household.servings = max(HouseholdStore.servingsRange.lowerBound, household.servings - 1) }
                    .disabled(household.servings <= HouseholdStore.servingsRange.lowerBound)
                Text("\(household.servings)")
                    .font(.headline.monospacedDigit()).foregroundStyle(KindredTheme.text)
                    .frame(minWidth: 20)
                    .contentTransition(.numericText())
                stepButton(system: "plus") { household.servings = min(HouseholdStore.servingsRange.upperBound, household.servings + 1) }
                    .disabled(household.servings >= HouseholdStore.servingsRange.upperBound)
            }
            Spacer()
            Text(household.servings == 2 ? "Just the two of you" : "\(household.servings) at the table")
                .font(.caption2).foregroundStyle(KindredTheme.faint)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Serves \(household.servings)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: household.servings = min(HouseholdStore.servingsRange.upperBound, household.servings + 1)
            case .decrement: household.servings = max(HouseholdStore.servingsRange.lowerBound, household.servings - 1)
            default: break
            }
        }
    }

    /// "Make it special" — a date-night bias offered only when cooking for one
    /// or two. Toggling regenerates the feed (folded into the household signature).
    private var specialToggle: some View {
        @Bindable var household = household
        return Toggle(isOn: $household.specialOccasion) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption).foregroundStyle(household.specialOccasion ? KindredTheme.amber : KindredTheme.faint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Make it special").font(.subheadline.weight(.semibold))
                        .foregroundStyle(KindredTheme.text)
                    Text("Date-night dinner — a nicer main, dessert & a pairing")
                        .font(.caption2).foregroundStyle(KindredTheme.faint)
                }
            }
        }
        .tint(KindredTheme.accent)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func stepButton(system: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { action() }
        } label: {
            Image(systemName: system)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(KindredTheme.accent)
                .frame(width: 30, height: 30)
                .background(KindredTheme.accent.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
    }

    /// Pinned horizontal meal-type filter so a breakfast (or any type) is one
    /// tap away instead of a scroll.
    private func mealTypeSelector(present: [MealType], effective: MealType?, hasOnHandOnly: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                typeChip(title: "All", icon: "square.grid.2x2",
                         isSelected: effective == nil) { selectedMealType = nil }
                if hasOnHandOnly {
                    typeChip(title: "No shopping", icon: "checkmark.circle",
                             isSelected: onHandOnly) { onHandOnly.toggle() }
                }
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
        .trailingChipFade()
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
        .environment(MealPlanStore())
        .environment(TasteFeedbackStore())
        .preferredColorScheme(.dark)
}
