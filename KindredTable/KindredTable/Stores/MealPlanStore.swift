import Foundation
import Observation

/// The weekly meal plan: recipes assigned to days, persisted locally. Feeds the
/// grocery list (which already de-dupes + aisle-sorts) for one-tap week shopping.
@Observable
final class MealPlanStore {

    private(set) var meals: [PlannedMeal] = []

    private let fileName = "meal_plan.json"
    private let calendar = Calendar.current

    init(seed: [PlannedMeal]? = nil) {
        meals = seed ?? LocalStore.load([PlannedMeal].self, from: fileName) ?? []
    }

    // MARK: Days

    /// The next 7 days starting today (start-of-day), for the planner grid.
    func upcomingDays(from today: Date = Date()) -> [Date] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func meals(on day: Date) -> [PlannedMeal] {
        meals.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: Mutations

    func add(_ recipe: Recipe, to day: Date) {
        meals.append(PlannedMeal(date: calendar.startOfDay(for: day), recipe: recipe))
        persist()
    }

    func remove(_ meal: PlannedMeal) {
        meals.removeAll { $0.id == meal.id }
        persist()
    }

    /// Drop everything before today so the plan doesn't accumulate stale days.
    func prunePast(now: Date = Date()) {
        let start = calendar.startOfDay(for: now)
        let before = meals.count
        meals.removeAll { $0.date < start }
        if meals.count != before { persist() }
    }

    // MARK: Derived

    var plannedCount: Int { meals.count }

    /// Total planned meals in the visible week.
    func count(in days: [Date]) -> Int {
        days.reduce(0) { $0 + meals(on: $1).count }
    }

    /// Every shopping item across all planned recipes (names; the GroceryStore
    /// de-dupes case-insensitively and files each into its aisle).
    func shoppingNames(for days: [Date]) -> [String] {
        days.flatMap { meals(on: $0) }.flatMap { $0.recipe.needsToBuy }
    }

    private func persist() {
        LocalStore.save(meals, to: fileName)
    }
}
