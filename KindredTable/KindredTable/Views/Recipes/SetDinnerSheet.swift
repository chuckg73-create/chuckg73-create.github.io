import SwiftUI

/// Pick a specific dinner for a day — for recurring theme nights (Tuesday
/// smashed burgers, Thursday pizza). Generates the recipe, sets it as that
/// night's dinner, and saves it to the cookbook.
struct SetDinnerSheet: View {
    let day: Date
    var onChange: () -> Void

    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()
    @State private var dish = ""
    @State private var extraDishes: [String] = []
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var repeatWeekly = false
    @State private var cookbookQuery = ""
    @FocusState private var focused: Bool

    private static let ideas = ["Smashed burgers", "Pizza night", "Taco night",
                                "Pasta", "Stir-fry", "Sheet-pan chicken", "Breakfast for dinner"]

    private var weekdayName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: day)
    }

    private var dishCount: Int { 1 + extraDishes.count }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("What's for dinner \(MealPlanView.dayLabel(day).lowercased())?")
                            .font(.title2).fontWeight(.bold).foregroundStyle(KindredTheme.text)
                        Text("Name a dish and we'll build the recipe, tuned to your taste, and add it to your cookbook.")
                            .font(.subheadline).foregroundStyle(KindredTheme.subtext)

                        Toggle(isOn: $repeatWeekly) {
                            Label("Repeat every \(weekdayName)", systemImage: "repeat")
                                .font(.subheadline.weight(.medium)).foregroundStyle(KindredTheme.text)
                        }
                        .tint(KindredTheme.accent)
                        .padding(14)
                        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))

                        HStack(spacing: 10) {
                            Image(systemName: "fork.knife").foregroundStyle(KindredTheme.accent)
                            TextField("e.g. smashed burgers", text: $dish)
                                .focused($focused)
                                .submitLabel(.go)
                                .onSubmit { generate() }
                        }
                        .padding(14)
                        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))

                        ThemeIdeaChips(items: Self.ideas) { idea in
                            dish = idea
                            generate()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Making a full menu? Add the rest of it.")
                                .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.faint)
                            TokenEditor(tokens: $extraDishes, placeholder: "e.g. asparagus, mashed potatoes",
                                        tint: KindredTheme.accent)
                        }

                        Button(action: generate) {
                            HStack(spacing: 8) {
                                if isWorking {
                                    ProgressView().controlSize(.small).tint(.white)
                                    Text(dishCount > 1 ? "Building your menu…" : "Building your recipe…")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text(dishCount > 1 ? "Build this menu (\(dishCount) dishes)" : "Set this dinner")
                                }
                            }
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(KindredTheme.brandGradient, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking || dish.trimmingCharacters(in: .whitespaces).isEmpty)

                        if let errorText {
                            Text(errorText).font(.caption).foregroundStyle(KindredTheme.amber)
                        }

                        if !saved.saved.isEmpty {
                            cookbookPicker
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Set dinner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { focused = true }
        }
    }

    private func generate() {
        let wanted = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty, !isWorking else { return }
        let others = extraDishes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard others.isEmpty else { generateMenu(dishes: [wanted] + others); return }

        focused = false
        isWorking = true
        errorText = nil
        Task {
            do {
                let recipes = try await service.craveRecipes(
                    dish: wanted,
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile),
                    count: 1,
                    servings: household.servings
                )
                guard let recipe = recipes.first else {
                    await MainActor.run { isWorking = false; errorText = "Couldn't build that one — try another dish." }
                    return
                }
                await MainActor.run { finish(recipe, isNew: true) }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorText = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    /// Builds a full recipe for every named dish in parallel — a whole menu
    /// (a main plus sides) for one night, each with its own directions, tips
    /// and back-timed cooking schedule that lands together at the night's
    /// sit-down time.
    private func generateMenu(dishes: [String]) {
        focused = false
        isWorking = true
        errorText = nil
        let profile = household.effectiveProfile(you: profileStore.profile)
        let ingredients = pantry.ingredients
        let servings = household.servings
        Task {
            let recipes = await withTaskGroup(of: Recipe?.self) { group -> [Recipe] in
                for name in dishes {
                    group.addTask {
                        try? await service.craveRecipes(dish: name, from: ingredients, profile: profile,
                                                        count: 1, servings: servings).first
                    }
                }
                var out: [Recipe] = []
                for await r in group { if let r { out.append(r) } }
                return out
            }
            guard !recipes.isEmpty else {
                await MainActor.run {
                    isWorking = false
                    errorText = "Couldn't build that menu — try again."
                }
                return
            }
            await MainActor.run { finishMenu(recipes) }
        }
    }

    /// Sets the day's dinner and, if the cook toggled it, makes it a standing
    /// weekly theme. Shared by both the generate-a-dish path and picking
    /// straight from the cookbook.
    private func finish(_ recipe: Recipe, isNew: Bool) {
        mealPlan.setDinner(recipe, on: day)   // replaces whatever was there
        if isNew { saved.add(recipe) }        // a fresh generation joins the cookbook
        if repeatWeekly {
            mealPlan.setRecurring(recipe, weekday: Calendar.current.component(.weekday, from: day))
        }
        onChange()
        dismiss()
    }

    /// Sets every dish of a generated menu at once. `repeatWeekly` — if on —
    /// applies to the first (main) dish only; `RecurringTheme` models one
    /// recipe per weekday.
    private func finishMenu(_ recipes: [Recipe]) {
        mealPlan.setMenu(recipes, on: day)
        for recipe in recipes { saved.add(recipe) }
        if repeatWeekly, let main = recipes.first {
            mealPlan.setRecurring(main, weekday: Calendar.current.component(.weekday, from: day))
        }
        onChange()
        dismiss()
    }

    // MARK: Pick from cookbook

    @ViewBuilder private var cookbookPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle().fill(KindredTheme.hairline).frame(height: 1)
                Text("or pick from your cookbook").font(.caption).foregroundStyle(KindredTheme.faint)
                Rectangle().fill(KindredTheme.hairline).frame(height: 1)
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(KindredTheme.faint)
                TextField("Search your cookbook", text: $cookbookQuery)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(KindredTheme.text)
            }
            .padding(12)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            let trimmed = cookbookQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let matches = saved.saved.filter { CookbookView.matches($0, trimmed) }.prefix(8)
                if matches.isEmpty {
                    Text("No matches").font(.caption).foregroundStyle(KindredTheme.faint)
                } else {
                    ForEach(Array(matches)) { recipe in
                        cookbookRow(recipe)
                    }
                }
            }
        }
    }

    private func cookbookRow(_ recipe: Recipe) -> some View {
        Button { finish(recipe, isNew: false) } label: {
            HStack(spacing: 12) {
                RecipeHeroImage(recipe: recipe, height: 44, glyphSize: 18)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(KindredTheme.text).lineLimit(1)
                    if !recipe.attribution.isEmpty {
                        Text(recipe.attribution).font(.caption2).foregroundStyle(KindredTheme.coral)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(KindredTheme.faint)
            }
            .padding(10)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A simple wrapping row of tappable suggestion chips.
private struct ThemeIdeaChips: View {
    let items: [String]
    var onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(KindredTheme.text)
                        .background(KindredTheme.accent.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
