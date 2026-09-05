import Foundation

/// A recipe placed on a specific day of the week's meal plan. Stores a full
/// recipe snapshot so the plan stays stable even if the source changes.
struct PlannedMeal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date          // start-of-day
    var recipe: Recipe
    /// Full datetime the cook plans to sit down; nil = use the usual dinner time.
    var serveTime: Date?
    /// Number of people eating that night; nil = use the recipe's own servings.
    var headcount: Int?
}

/// A standing "theme night" — the same recipe every week on one weekday
/// (Tuesday smashed burgers, Thursday pizza) until the cook clears it.
struct RecurringTheme: Codable, Hashable {
    /// `Calendar` weekday numbering: 1 = Sunday … 7 = Saturday.
    var weekday: Int
    var recipe: Recipe
}
