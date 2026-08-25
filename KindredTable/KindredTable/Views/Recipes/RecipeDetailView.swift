import SwiftUI
import UIKit

/// Full recipe view with ingredients, steps, and save-for-later.
struct RecipeDetailView: View {
    @State private var recipe: Recipe
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(ProfileStore.self) private var profileStore
    @Environment(GroceryStore.self) private var grocery
    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(HouseholdStore.self) private var household
    @Environment(TasteFeedbackStore.self) private var feedback
    @Environment(RecipeNotesStore.self) private var notesStore
    @State private var noteDraft = ""
    @FocusState private var noteFocused: Bool
    @State private var plannedDay: Date?
    /// The ingredient the cook is swapping (drives the substitute sheet).
    @State private var substituteTarget: RecipeIngredient?
    @State private var addedToList = false
    /// Keeps the display awake while cooking (no auto-lock).
    @State private var keepAwake = false
    @State private var showCookMode = false
    @State private var showPlan = false
    @State private var showEdit = false
    /// Target servings for on-the-fly scaling; starts at the recipe's own yield.
    @State private var displayServings: Int
    /// "Polish with KindredTable" state for imported recipes.
    @State private var isPolishing = false
    @State private var polished = false
    @State private var polishError: String?

    init(recipe: Recipe) {
        _recipe = State(initialValue: recipe)
        _displayServings = State(initialValue: max(1, recipe.servings))
    }

    /// Offer to polish an imported recipe only while it still looks un-enriched.
    private var canPolish: Bool {
        recipe.source.isImported && !polished && recipe.tips.isEmpty && recipe.cooksNotes.isEmpty
    }

    /// The recipe with amounts scaled to `displayServings` (identity when equal).
    private var displayed: Recipe { RecipeScaler.scaled(recipe, to: displayServings) }
    private var isScaled: Bool { displayServings != max(1, recipe.servings) }

    var body: some View {
        ZStack {
            KindredBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RecipeHeroImage(recipe: recipe, height: 210, glyphSize: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    header
                    if canPolish || isPolishing { polishCard }
                    if !recipe.steps.isEmpty { cookModeButton }
                    addToPlanButton
                    if !recipe.steps.isEmpty { planButton }
                    if !recipe.whyYoullLikeIt.isEmpty { whyCard }
                    if let n = recipe.nutrition, n.hasAny { nutritionCard(n) }
                    ingredientsCard
                    stepsCard
                    ratingCard
                    notesCard
                    if !recipe.cooksNotes.isEmpty { cooksNotesCard }
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
        .sheet(isPresented: $showPlan) {
            CookPlanView(recipe: recipe)
        }
        .sheet(isPresented: $showEdit) {
            RecipeEditView(recipe: recipe) { edited in
                withAnimation { recipe = edited; displayServings = max(1, edited.servings) }
                if saved.isSaved(edited) { saved.update(edited) }
            }
        }
        .sheet(item: $substituteTarget) { ing in
            SubstituteSheet(recipe: recipe, ingredient: ing,
                            profile: household.effectiveProfile(you: profileStore.profile)) { updated in
                withAnimation { recipe = updated; displayServings = max(1, updated.servings) }
                if saved.isSaved(updated) { saved.update(updated) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: {
                    Image(systemName: "pencil").foregroundStyle(KindredTheme.accent)
                }
                .accessibilityLabel("Edit recipe")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: RecipeShare.text(for: displayed),
                          subject: Text(recipe.title),
                          preview: SharePreview(recipe.title)) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(KindredTheme.accent)
                }
                .accessibilityLabel("Share recipe")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saved.toggle(recipe)
                } label: {
                    Image(systemName: saved.isSaved(recipe) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(saved.isSaved(recipe) ? KindredTheme.amber : KindredTheme.accent)
                }
                .accessibilityLabel(saved.isSaved(recipe) ? "Saved" : "Save recipe")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(recipe.title)
                    .font(.title).fontWeight(.bold)
                Spacer()
                if recipe.source.isImported {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title2).foregroundStyle(KindredTheme.coral)
                } else {
                    MatchBadge(score: recipe.matchScore)
                }
            }
            if recipe.source.isImported, !recipe.attribution.isEmpty {
                Label(recipe.attribution, systemImage: "quote.opening")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(KindredTheme.coral)
            }
            Text(recipe.summary)
                .foregroundStyle(KindredTheme.subtext)
            HStack(spacing: 14) {
                Label("Serves \(displayed.servings)", systemImage: "person.2.fill")
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

    private var addToPlanButton: some View {
        Menu {
            ForEach(mealPlan.upcomingDays(), id: \.self) { day in
                Button(MealPlanView.dayLabel(day)) {
                    mealPlan.add(recipe, to: day)
                    withAnimation { plannedDay = day }
                }
            }
        } label: {
            Label(plannedDay == nil ? "Add to meal plan" : "Added to \(MealPlanView.dayLabel(plannedDay!))",
                  systemImage: plannedDay == nil ? "calendar.badge.plus" : "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(plannedDay == nil ? KindredTheme.accent : KindredTheme.mint)
                .background((plannedDay == nil ? KindredTheme.accent : KindredTheme.mint).opacity(0.14),
                           in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var planButton: some View {
        Button { showPlan = true } label: {
            Label("Cook by a time — schedule reminders", systemImage: "bell.badge.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(KindredTheme.accent)
                .background(KindredTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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

    private func nutritionCard(_ n: NutritionInfo) -> some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(label: "Nutrition")
                    Spacer()
                    Text("Per serving · estimated")
                        .font(.caption2).foregroundStyle(KindredTheme.faint)
                }
                HStack(spacing: 10) {
                    nutrientStat("\(n.calories)", "cal", KindredTheme.amber)
                    nutrientStat("\(n.protein)g", "protein", KindredTheme.mint)
                    nutrientStat("\(n.carbs)g", "carbs", KindredTheme.blue)
                    nutrientStat("\(n.fat)g", "fat", KindredTheme.coral)
                }
            }
        }
    }

    private func nutrientStat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline).foregroundStyle(KindredTheme.text)
            Text(label).font(.caption2).foregroundStyle(KindredTheme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    Label("Tap to swap", systemImage: "arrow.left.arrow.right")
                        .font(.caption2).foregroundStyle(KindredTheme.faint)
                }
                scaleControl
                ForEach(Array(displayed.ingredients.enumerated()), id: \.offset) { idx, ing in
                    ingredientRow(ing, base: idx < recipe.ingredients.count ? recipe.ingredients[idx] : ing)
                }
                if !displayed.needsToBuy.isEmpty {
                    Button {
                        grocery.addMany(displayed.needsToBuy)
                        withAnimation { addedToList = true }
                    } label: {
                        Label(
                            addedToList ? "Added to grocery list" : "Add \(displayed.needsToBuy.count) to grocery list",
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

    /// Scale-to-servings control: amounts rescale live, on-device. The heart of
    /// cooking Mom's 6-serving recipe for just the two of you.
    private var scaleControl: some View {
        HStack(spacing: 10) {
            Label("Scale to", systemImage: "slider.horizontal.3")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
            Spacer()
            HStack(spacing: 14) {
                scaleStep(system: "minus") {
                    displayServings = max(1, displayServings - 1)
                }
                .disabled(displayServings <= 1)
                Text("\(displayServings)")
                    .font(.headline.monospacedDigit()).foregroundStyle(KindredTheme.text)
                    .frame(minWidth: 20).contentTransition(.numericText())
                scaleStep(system: "plus") {
                    displayServings = min(24, displayServings + 1)
                }
                .disabled(displayServings >= 24)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(KindredTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomLeading) {
            if isScaled {
                Text("Scaled from the original \(recipe.servings)")
                    .font(.caption2).foregroundStyle(KindredTheme.faint)
                    .padding(.leading, 12).padding(.bottom, -16)
            }
        }
        .padding(.bottom, isScaled ? 16 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scale to \(displayServings) servings")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: displayServings = min(24, displayServings + 1)
            case .decrement: displayServings = max(1, displayServings - 1)
            default: break
            }
        }
    }

    private func scaleStep(system: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { action() }
        } label: {
            Image(systemName: system)
                .font(.subheadline.weight(.bold)).foregroundStyle(KindredTheme.accent)
                .frame(width: 30, height: 30)
                .background(KindredTheme.accent.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func ingredientRow(_ ing: RecipeIngredient, base: RecipeIngredient) -> some View {
        Button { substituteTarget = base } label: {
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
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2).foregroundStyle(KindredTheme.faint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    /// Imported recipes: an opt-in offer to add tips and flag gaps, without
    /// touching the original.
    private var polishCard: some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wand.and.stars").foregroundStyle(KindredTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Polish with KindredTable")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.text)
                        Text("Add chef tips and spot anything the handwriting left out — like a missing oven temperature. Your original stays exactly as written.")
                            .font(.caption).foregroundStyle(KindredTheme.subtext)
                    }
                }
                if let polishError {
                    Text(polishError).font(.caption).foregroundStyle(KindredTheme.amber)
                }
                Button { polish() } label: {
                    HStack(spacing: 8) {
                        if isPolishing {
                            ProgressView().controlSize(.small).tint(.white)
                            Text("Reading it over…")
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("Add tips & check for gaps")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isPolishing)
            }
        }
    }

    private var cooksNotesCard: some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.caption).foregroundStyle(KindredTheme.accent)
                    SectionHeader(label: "KindredTable's notes")
                }
                Text("Suggestions for what the original recipe didn't spell out:")
                    .font(.caption).foregroundStyle(KindredTheme.faint)
                ForEach(recipe.cooksNotes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption).foregroundStyle(KindredTheme.blue)
                        Text(note).font(.subheadline)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func polish() {
        polishError = nil
        isPolishing = true
        Task {
            do {
                let service = GeminiRecipeService()
                let enriched = try await service.enrich(recipe, profile: profileStore.profile)
                await MainActor.run {
                    withAnimation {
                        recipe = enriched
                        polished = true
                        isPolishing = false
                    }
                    saved.update(enriched)   // persist if it's in the cookbook
                }
            } catch {
                await MainActor.run {
                    isPolishing = false
                    polishError = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    /// Personal notes on this recipe ("used less salt", "kids loved it").
    private var notesCard: some View {
        KindredCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(label: "Your notes")
                    Spacer()
                    if noteFocused {
                        Button("Done") { saveNote(); noteFocused = false }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.accent)
                    }
                }
                TextField("Add a note — tweaks, who loved it, what to change next time…",
                          text: $noteDraft, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.subheadline).foregroundStyle(KindredTheme.text)
                    .focused($noteFocused)
                    .onChange(of: noteFocused) { _, focused in if !focused { saveNote() } }
            }
        }
        .onAppear { noteDraft = notesStore.note(for: recipe) }
    }

    private func saveNote() { notesStore.setNote(noteDraft, for: recipe) }

    /// The taste flywheel: rate a dish you made and KindredTable learns from it.
    private var ratingCard: some View {
        let current = feedback.verdict(for: recipe)
        return KindredCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(label: current == nil ? "Made it? Rate it" : "You rated this")
                Text(current == nil
                     ? "Tell KindredTable how it turned out — it learns your taste and matches better next time."
                     : "Thanks — this sharpens your future ideas. Tap to change.")
                    .font(.caption).foregroundStyle(KindredTheme.subtext)
                HStack(spacing: 10) {
                    ForEach(RecipeVerdict.allCases) { v in
                        Button {
                            withAnimation {
                                if current == v { feedback.clear(recipe) }
                                else {
                                    feedback.record(recipe, verdict: v)
                                    if v == .loved, !saved.isSaved(recipe) { saved.toggle(recipe) }
                                }
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: v.systemImage).font(.title3)
                                Text(v.title).font(.caption2)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(current == v ? Color.white : Self.verdictTint(v))
                            .background(current == v ? AnyShapeStyle(Self.verdictTint(v))
                                                    : AnyShapeStyle(Self.verdictTint(v).opacity(0.12)),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if current == .loved {
                    Label("Saved to your cookbook", systemImage: "bookmark.fill")
                        .font(.caption2).foregroundStyle(KindredTheme.mint)
                }
            }
        }
    }

    private static func verdictTint(_ v: RecipeVerdict) -> Color {
        switch v {
        case .loved: return KindredTheme.coral
        case .liked: return KindredTheme.mint
        case .disliked: return KindredTheme.faint
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
            .environment(ProfileStore(seed: .starter))
            .environment(GroceryStore())
            .environment(MealPlanStore())
            .environment(HouseholdStore())
            .environment(TasteFeedbackStore())
            .environment(RecipeNotesStore())
    }
    .preferredColorScheme(.dark)
}
