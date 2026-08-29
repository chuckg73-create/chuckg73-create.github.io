import SwiftUI

/// "Make a meal" — a flexible recipe request. Optionally name a dish, choose
/// ingredients to build around (type or pick from your pantry), pick a course
/// (side, soup, salad…), the equipment to use, and whether to lean on what you
/// have. Results open in the normal recipe detail (with Add-to-grocery).
struct CraveSearchView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(HouseholdStore.self) private var household
    @Environment(TasteFeedbackStore.self) private var feedback
    @Environment(TastePreferenceStore.self) private var preferences
    @Environment(StaplesStore.self) private var staples
    @Environment(\.dismiss) private var dismiss

    /// Rated dishes + hand-tuned steering + pantry staples, for the prompt.
    private var tasteSignals: String? {
        let combined = [feedback.promptSummary(), preferences.promptLine(), staples.promptLine()]
            .compactMap { $0 }
            .joined(separator: "\n")
        return combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : combined
    }

    @State private var request = MealRequest()
    @State private var ingredientDraft = ""
    @State private var phase: Phase = .idle
    private let service = GeminiRecipeService()

    enum Phase: Equatable {
        case idle, loading
        case results([Recipe])
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        dishField
                        includeSection
                        courseSection
                        equipmentSection
                        onHandToggle
                        generateButton
                        results
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Make a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    // MARK: Sections

    private var dishField: some View {
        section("Craving something specific?", trailing: "Optional") {
            HStack(spacing: 10) {
                Image(systemName: "fork.knife").foregroundStyle(KindredTheme.accent)
                TextField("e.g. chicken parmesan (or leave blank)", text: $request.dish)
                    .foregroundStyle(KindredTheme.text)
                    .submitLabel(.search)
                    .onSubmit(run)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var includeSection: some View {
        section("Use these ingredients", trailing: "What you want in it") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Add an ingredient — e.g. diced chicken", text: $ingredientDraft)
                        .foregroundStyle(KindredTheme.text)
                        .autocorrectionDisabled()
                        .onSubmit(addIngredient)
                    Button(action: addIngredient) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(KindredTheme.accent)
                    }
                    .disabled(ingredientDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12))

                if !request.includeIngredients.isEmpty {
                    wrap(request.includeIngredients) { item in
                        chip(item, systemImage: "checkmark", isOn: true) {
                            request.includeIngredients.removeAll { $0 == item }
                        }
                    }
                }

                let picks = pantryQuickPicks
                if !picks.isEmpty {
                    Text("Quick add from your pantry").font(.caption).foregroundStyle(KindredTheme.faint)
                    wrap(picks) { name in
                        chip(name, systemImage: "plus", isOn: false) {
                            request.includeIngredients.append(name)
                        }
                    }
                }
            }
        }
    }

    private var courseSection: some View {
        section("What kind of dish?") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Course.allCases) { c in
                        chip(c.title, systemImage: c.systemImage, isOn: request.course == c) {
                            request.course = c
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
    }

    private var equipmentSection: some View {
        section("Cook with", trailing: "Optional") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(equipmentOptions, id: \.self) { e in
                        let on = request.equipment.contains(e)
                        chip(e, systemImage: on ? "checkmark" : nil, isOn: on) {
                            if on { request.equipment.removeAll { $0 == e } }
                            else { request.equipment.append(e) }
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
    }

    private var onHandToggle: some View {
        Toggle(isOn: $request.preferOnHand) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Use mostly what I have").foregroundStyle(KindredTheme.text)
                Text("Lean on your pantry; minimize the shopping list.")
                    .font(.caption).foregroundStyle(KindredTheme.faint)
            }
        }
        .tint(KindredTheme.accent)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var generateButton: some View {
        Button(action: run) {
            Label("Find recipes", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(KindredTheme.accent)
        .disabled(request.isEmpty || phase == .loading)
    }

    @ViewBuilder private var results: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .loading:
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(KindredTheme.accent)
                Text("Building your recipes…").foregroundStyle(KindredTheme.subtext)
            }
            .frame(maxWidth: .infinity).padding(.top, 24)
        case .results(let recipes):
            VStack(spacing: 14) {
                ForEach(recipes) { recipe in
                    NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                        RecipeCard(recipe: recipe, isSaved: saved.isSaved(recipe), onSave: { saved.toggle(recipe) })
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        case .failed(let message):
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").font(.title).foregroundStyle(KindredTheme.amber)
                Text(message).font(.subheadline).foregroundStyle(KindredTheme.subtext).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.top, 20)
        }
    }

    // MARK: Helpers

    private var pantryQuickPicks: [String] {
        pantry.ingredients.map(\.name)
            .filter { name in !request.includeIngredients.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
            .prefix(8).map { $0 }
    }

    private var equipmentOptions: [String] {
        var seen = Set<String>(); var out: [String] = []
        for e in profileStore.profile.equipment + MealRequest.commonEquipment {
            let key = e.lowercased()
            if !seen.contains(key) { seen.insert(key); out.append(e) }
        }
        return out
    }

    private func section<Content: View>(_ title: String, trailing: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline).foregroundStyle(KindredTheme.text)
                if let trailing { Spacer(); Text(trailing).font(.caption).foregroundStyle(KindredTheme.faint) }
            }
            content()
        }
    }

    private func wrap<Content: View>(_ items: [String], @ViewBuilder _ item: @escaping (String) -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item($0) }
        }
    }

    private func chip(_ text: String, systemImage: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.caption2) }
                Text(text).font(.subheadline)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(isOn ? Color.white : KindredTheme.subtext)
            .background(isOn ? AnyShapeStyle(KindredTheme.brandGradient) : AnyShapeStyle(KindredTheme.card), in: Capsule())
            .overlay(Capsule().stroke(isOn ? Color.clear : KindredTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func addIngredient() {
        let t = ingredientDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !request.includeIngredients.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else {
            ingredientDraft = ""; return
        }
        request.includeIngredients.append(t)
        ingredientDraft = ""
    }

    private func run() {
        guard !request.isEmpty else { return }
        phase = .loading
        Task {
            do {
                let recipes = try await service.makeMeal(
                    request,
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile),
                    servings: household.servings,
                    special: household.specialOccasion,
                    tasteFeedback: tasteSignals
                )
                phase = .results(recipes)
            } catch {
                let message = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                phase = .failed(message)
            }
        }
    }
}
