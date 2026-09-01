import Foundation

/// Formats the week's dinner plan as clean plain text for the share sheet — so a
/// cook can text the week (and its shopping list) to a partner or the family,
/// whether or not they have the app.
enum MealPlanShare {

    static func text(days: [Date], store: MealPlanStore) -> String {
        var lines: [String] = ["This week's dinners"]

        for day in days {
            let meals = store.meals(on: day)
            guard !meals.isEmpty else { continue }
            for meal in meals {
                let time = MealPlanView.timeStr(store.serveTime(for: meal))
                let serves = store.headcount(for: meal)
                lines.append("")
                lines.append("\(MealPlanView.dayLabel(day)) · \(time) · serves \(serves)")
                lines.append(meal.recipe.title)
            }
        }

        // Consolidated shopping list (case-insensitive de-dupe, order preserved).
        var seen = Set<String>()
        var shopping: [String] = []
        for name in store.shoppingNames(for: days) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            shopping.append(trimmed)
        }
        if !shopping.isEmpty {
            lines.append("")
            lines.append("SHOPPING LIST")
            for item in shopping { lines.append("• \(item)") }
        }

        lines.append("")
        lines.append("Planned with KindredTable 🍽️")
        lines.append("https://chuckg73-create.github.io/kindredkitchen/")
        return lines.joined(separator: "\n")
    }
}
