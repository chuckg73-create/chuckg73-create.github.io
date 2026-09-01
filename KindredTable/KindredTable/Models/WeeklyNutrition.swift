import Foundation

/// A per-serving nutrition average across the week's planned dinners — a gentle
/// at-a-glance sense of how the week is shaping up, not a medical tracker.
struct WeeklyNutrition: Hashable {
    var count: Int          // planned dinners that carry nutrition
    var avgCalories: Int
    var avgProtein: Int
    var avgCarbs: Int
    var avgFat: Int

    /// Average the per-serving macros over every recipe that has nutrition;
    /// returns nil when none do (so the card simply doesn't show).
    static func summarize(_ recipes: [Recipe]) -> WeeklyNutrition? {
        let infos = recipes.compactMap(\.nutrition).filter(\.hasAny)
        guard !infos.isEmpty else { return nil }
        let n = infos.count
        func avg(_ value: (NutritionInfo) -> Int) -> Int { infos.map(value).reduce(0, +) / n }
        return WeeklyNutrition(
            count: n,
            avgCalories: avg { $0.calories },
            avgProtein: avg { $0.protein },
            avgCarbs: avg { $0.carbs },
            avgFat: avg { $0.fat }
        )
    }
}
