import Foundation
import Observation

/// The weekly meal plan: recipes assigned to days, persisted locally. Feeds the
/// grocery list (which already de-dupes + aisle-sorts) for one-tap week shopping.
@Observable
final class MealPlanStore {

    private(set) var meals: [PlannedMeal] = []

    /// The cook's usual sit-down time, used as each night's default.
    private(set) var usualDinnerHour: Int
    private(set) var usualDinnerMinute: Int

    private let fileName = "meal_plan.json"
    private let settingsFile = "meal_plan_settings.json"
    private let calendar = Calendar.current

    private struct Settings: Codable { var hour: Int; var minute: Int }

    init(seed: [PlannedMeal]? = nil) {
        meals = seed ?? LocalStore.load([PlannedMeal].self, from: fileName) ?? []
        let s = LocalStore.load(Settings.self, from: settingsFile)
        usualDinnerHour = s?.hour ?? 18
        usualDinnerMinute = s?.minute ?? 30
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

    /// Set a night's dinner to a specific recipe, replacing whatever was there —
    /// for recurring "theme nights" (Tuesday smashed burgers, Thursday pizza).
    func setDinner(_ recipe: Recipe, on day: Date) {
        let start = calendar.startOfDay(for: day)
        meals.removeAll { calendar.isDate($0.date, inSameDayAs: start) }
        meals.append(PlannedMeal(date: start, recipe: recipe))
        persist()
    }

    func remove(_ meal: PlannedMeal) {
        meals.removeAll { $0.id == meal.id }
        persist()
    }

    // MARK: Dinner time + headcount

    /// The sit-down time for a meal — its own override, else the usual time on its day.
    func serveTime(for meal: PlannedMeal) -> Date {
        if let t = meal.serveTime { return t }
        return calendar.date(bySettingHour: usualDinnerHour, minute: usualDinnerMinute, second: 0, of: meal.date) ?? meal.date
    }

    /// People eating that night — the meal's override, else the recipe's servings.
    func headcount(for meal: PlannedMeal) -> Int {
        meal.headcount ?? max(1, meal.recipe.servings)
    }

    func setServeTime(_ date: Date?, for meal: PlannedMeal) {
        guard let i = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[i].serveTime = date
        persist()
    }

    func setHeadcount(_ count: Int?, for meal: PlannedMeal) {
        guard let i = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[i].headcount = count
        persist()
    }

    func setUsualDinnerTime(_ date: Date) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        usualDinnerHour = c.hour ?? 18
        usualDinnerMinute = c.minute ?? 30
        LocalStore.save(Settings(hour: usualDinnerHour, minute: usualDinnerMinute), to: settingsFile)
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
