import SwiftUI

/// The week's meal plan: seven days, the recipes planned for each, and one tap
/// to turn the whole week into a consolidated, aisle-sorted grocery list.
struct MealPlanView: View {
    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(GroceryStore.self) private var grocery
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(TasteFeedbackStore.self) private var feedback
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()
    @State private var addedCount: Int?
    @State private var isPlanning = false
    @State private var planError: String?

    private var days: [Date] { mealPlan.upcomingDays() }
    private var emptyDays: [Date] { days.filter { mealPlan.meals(on: $0).isEmpty } }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                if mealPlan.count(in: days) == 0 {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("This week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            EmptyState(
                systemImage: "calendar",
                title: "Plan your week",
                message: "Let KindredTable fill your week with taste-matched dinners in one tap — or open any recipe and tap “Add to meal plan.”"
            )
            autoPlanButton.padding(.horizontal, 40)
            if let planError { Text(planError).font(.caption).foregroundStyle(KindredTheme.amber).padding(.horizontal, 40) }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if !emptyDays.isEmpty {
                        autoPlanButton
                        if let planError { Text(planError).font(.caption).foregroundStyle(KindredTheme.amber) }
                    }
                    ForEach(days, id: \.self) { day in
                        daySection(day)
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
            groceryBar
        }
    }

    /// One-tap: fill every empty upcoming day with a taste-matched dinner.
    private var autoPlanButton: some View {
        Button { planWeek() } label: {
            HStack(spacing: 8) {
                if isPlanning { ProgressView().controlSize(.small).tint(.white); Text("Planning your week…") }
                else { Image(systemName: "wand.and.stars"); Text("Auto-plan \(emptyDays.count) open day\(emptyDays.count == 1 ? "" : "s")") }
            }
            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPlanning || pantry.isEmpty || emptyDays.isEmpty)
    }

    private func planWeek() {
        let targets = emptyDays
        guard !targets.isEmpty else { return }
        guard !pantry.isEmpty else { planError = "Add a few ingredients first so we can match your week."; return }
        planError = nil
        isPlanning = true
        Task {
            do {
                // Fold a variety instruction into the taste-feedback slot so a
                // week's plan doesn't come back as the same protein seven times.
                let variety = "VARIETY: this is a full week's plan — vary the proteins, cuisines and cooking methods across the recipes so no two dinners feel too similar."
                let planNote = [feedback.promptSummary(), variety].compactMap { $0 }.joined(separator: "\n")
                let recipes = try await service.suggestRecipes(
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile),
                    count: targets.count,
                    servings: household.servings,
                    tasteFeedback: planNote,
                    useUpItems: pantry.useUpNames()
                )
                await MainActor.run {
                    for (day, recipe) in zip(targets, recipes) { mealPlan.add(recipe, to: day) }
                    addedCount = nil
                    isPlanning = false
                    if recipes.isEmpty { planError = "Couldn't build a plan right now — try again." }
                }
            } catch {
                await MainActor.run {
                    isPlanning = false
                    planError = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func daySection(_ day: Date) -> some View {
        let meals = mealPlan.meals(on: day)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Self.dayLabel(day)).font(.headline).foregroundStyle(KindredTheme.text)
                Spacer()
                if !meals.isEmpty {
                    Text("\(meals.count)").font(.caption).foregroundStyle(KindredTheme.faint)
                }
            }
            if meals.isEmpty {
                Text("Nothing planned")
                    .font(.subheadline).foregroundStyle(KindredTheme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(KindredTheme.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(meals) { meal in
                    NavigationLink {
                        RecipeDetailView(recipe: meal.recipe)
                    } label: {
                        mealRow(meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mealRow(_ meal: PlannedMeal) -> some View {
        HStack(spacing: 12) {
            RecipeHeroImage(recipe: meal.recipe, height: 52, glyphSize: 22)
                .frame(width: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.recipe.title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(KindredTheme.text).lineLimit(1)
                Text(meal.recipe.mealType.title).font(.caption).foregroundStyle(KindredTheme.subtext)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation { mealPlan.remove(meal); addedCount = nil }
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(KindredTheme.faint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(meal.recipe.title)")
        }
        .padding(10)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))
    }

    private var groceryBar: some View {
        let names = mealPlan.shoppingNames(for: days)
        let unique = Set(names.map { $0.lowercased() }).count
        return VStack(spacing: 6) {
            Button {
                let added = grocery.addMany(names)
                withAnimation { addedCount = added }
            } label: {
                Label(addedCount != nil ? "Added \(addedCount!) to grocery list" : "Add this week to grocery — \(unique) items",
                      systemImage: addedCount != nil ? "checkmark.circle.fill" : "cart.badge.plus")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(addedCount != nil ? AnyShapeStyle(KindredTheme.mint) : AnyShapeStyle(KindredTheme.brandGradient),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(unique == 0)
            Text("Combined across every planned recipe, sorted by aisle.")
                .font(.caption2).foregroundStyle(KindredTheme.faint)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: Date label

    static func dayLabel(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)),
           cal.isDate(date, inSameDayAs: tomorrow) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: date)
    }
}
