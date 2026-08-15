import Foundation

/// Formats a recipe as clean, plain text for the iOS share sheet — so it can go
/// to anyone, in any app (Messages, Mail, WhatsApp, Notes, print), whether or
/// not they have Kindred Kitchen. Shares whatever is on screen, including the
/// current serving scale.
enum RecipeShare {

    static func text(for recipe: Recipe) -> String {
        var lines: [String] = []

        lines.append(recipe.title)
        let attribution = recipe.attribution
        if !attribution.isEmpty { lines.append(attribution) }
        if !recipe.summary.isEmpty { lines.append(recipe.summary) }

        // Meta line: Serves · time · difficulty
        var meta: [String] = ["Serves \(recipe.servings)"]
        if recipe.totalMinutes > 0 { meta.append("\(recipe.totalMinutes) min") }
        meta.append(recipe.difficulty.title)
        lines.append("")
        lines.append(meta.joined(separator: " · "))

        if !recipe.ingredients.isEmpty {
            lines.append("")
            lines.append("INGREDIENTS")
            for ing in recipe.ingredients {
                lines.append("• \(ing.display)")
            }
        }

        if !recipe.steps.isEmpty {
            lines.append("")
            lines.append("METHOD")
            for (i, step) in recipe.steps.enumerated() {
                lines.append("\(i + 1). \(step)")
            }
        }

        if !recipe.tips.isEmpty {
            lines.append("")
            lines.append("TIPS")
            for tip in recipe.tips { lines.append("• \(tip)") }
        }

        if !recipe.cooksNotes.isEmpty {
            lines.append("")
            lines.append("NOTES")
            for note in recipe.cooksNotes { lines.append("• \(note)") }
        }

        lines.append("")
        lines.append("— Shared from Kindred Kitchen 🍳")

        return lines.joined(separator: "\n")
    }
}
