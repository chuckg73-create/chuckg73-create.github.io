import SwiftUI

/// The week's meal plan: seven days, the recipes planned for each, and one tap
/// to turn the whole week into a consolidated, aisle-sorted grocery list.
struct MealPlanView: View {
    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(GroceryStore.self) private var grocery
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(\.dismiss) private var dismiss

    @State private var addedCount: Int?

    private var days: [Date] { mealPlan.upcomingDays() }

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
                message: "Open any recipe and tap “Add to meal plan” to drop it on a day. Then turn the whole week into one shopping list."
            )
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
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
