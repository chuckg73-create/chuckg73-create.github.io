import Foundation
import Observation

/// Remembers how dishes actually turned out and feeds that back into the recipe
/// engine, so suggestions sharpen toward what the cook loves and away from what
/// they didn't. The taste flywheel: cook → rate → better matches.
@Observable
final class TasteFeedbackStore {

    private(set) var ratings: [RecipeRating] = []

    private let fileName = "taste_feedback.json"

    init(seed: [RecipeRating]? = nil) {
        ratings = seed ?? LocalStore.load([RecipeRating].self, from: fileName) ?? []
    }

    /// Record (or update) how a made dish turned out. One rating per title.
    func record(_ recipe: Recipe, verdict: RecipeVerdict, now: Date = Date()) {
        ratings.removeAll { $0.recipeTitle.caseInsensitiveCompare(recipe.title) == .orderedSame }
        ratings.insert(RecipeRating(recipeTitle: recipe.title, verdict: verdict,
                                    tags: recipe.tags, mealType: recipe.mealType.rawValue, now: now),
                       at: 0)
        persist()
    }

    func verdict(for recipe: Recipe) -> RecipeVerdict? {
        ratings.first { $0.recipeTitle.caseInsensitiveCompare(recipe.title) == .orderedSame }?.verdict
    }

    func clear(_ recipe: Recipe) {
        ratings.removeAll { $0.recipeTitle.caseInsensitiveCompare(recipe.title) == .orderedSame }
        persist()
    }

    var lovedCount: Int { ratings.lazy.filter { $0.verdict == .loved }.count }
    var isEmpty: Bool { ratings.isEmpty }

    /// Distinct tags (cuisines/descriptors) from dishes the cook has loved —
    /// the learned side of their taste, used to explain why a recipe matched.
    var lovedTags: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for rating in ratings where rating.verdict == .loved {
            for tag in rating.tags where seen.insert(tag.lowercased()).inserted {
                out.append(tag)
            }
        }
        return out
    }

    /// A compact summary of recent taste feedback for the recipe prompt, or nil
    /// when there's nothing to learn from yet.
    func promptSummary(lovedLimit: Int = 8, dislikedLimit: Int = 6) -> String? {
        let loved = ratings.filter { $0.verdict == .loved }.prefix(lovedLimit)
        let disliked = ratings.filter { $0.verdict == .disliked }.prefix(dislikedLimit)
        guard !loved.isEmpty || !disliked.isEmpty else { return nil }

        var lines = ["RECENT TASTE FEEDBACK — learn from what the cook actually made and rated:"]
        if !loved.isEmpty {
            lines.append("- Loved: \(loved.map(describe).joined(separator: "; ")). Lean toward these flavors, cuisines and styles.")
        }
        if !disliked.isEmpty {
            lines.append("- Didn't enjoy: \(disliked.map(describe).joined(separator: "; ")). Avoid dishes like these.")
        }
        return lines.joined(separator: "\n")
    }

    private func describe(_ r: RecipeRating) -> String {
        let tags = r.tags.prefix(3).joined(separator: ", ")
        return tags.isEmpty ? r.recipeTitle : "\(r.recipeTitle) (\(tags))"
    }

    private func persist() {
        LocalStore.save(ratings, to: fileName)
    }
}

private extension RecipeRating {
    init(recipeTitle: String, verdict: RecipeVerdict, tags: [String], mealType: String, now: Date) {
        self.init(id: UUID(), recipeTitle: recipeTitle, verdict: verdict, tags: tags, mealType: mealType, date: now)
    }
}
