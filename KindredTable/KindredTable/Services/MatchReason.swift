import Foundation

/// Builds a short, *always-true* explanation of why a recipe fits this cook —
/// computed from real signals (loved cuisines, on-hand ingredients, dishes they've
/// rated, time, spice), never from model prose. This is what turns the "90% match"
/// badge from a black box into something the cook can trust and verify.
enum MatchReason {

    /// One-sentence reason, or `nil` for imported recipes / when nothing concrete
    /// matches (the caller can then fall back to the model's own blurb).
    static func sentence(for recipe: Recipe, profile: TasteProfile, lovedTags: [String] = []) -> String? {
        guard !recipe.source.isImported else { return nil }
        let parts = phrases(for: recipe, profile: profile, lovedTags: lovedTags)
        guard let first = parts.first else { return nil }
        let joined = parts.count == 1 ? first : "\(first) and \(parts[1])"
        return "Because \(joined)."
    }

    /// The ranked reason phrases (top two are used in the sentence). Public so a
    /// compact UI could show them as chips later.
    static func phrases(for recipe: Recipe, profile: TasteProfile, lovedTags: [String]) -> [String] {
        var out: [String] = []

        if let cuisine = lovedCuisine(in: recipe, profile: profile) {
            out.append("you love \(cuisine) food")
        }
        if let onHand = onHandPhrase(recipe) {
            out.append(onHand)
        }
        if let learned = learnedCuisine(in: recipe, lovedTags: lovedTags, excluding: profile.lovedCuisines) {
            out.append("you’ve loved other \(learned) dishes")
        }
        if let diet = dietFit(recipe, profile: profile) {
            out.append("it fits your \(diet.lowercased()) cooking")
        }
        if let quick = quickPhrase(recipe, profile: profile) {
            out.append(quick)
        }
        if spiceMatch(recipe, profile: profile) {
            out.append("it brings the heat you like")
        }
        return out
    }

    // MARK: Signals

    private static func lovedCuisine(in recipe: Recipe, profile: TasteProfile) -> String? {
        for loved in profile.lovedCuisines {
            if recipe.tags.contains(where: { $0.caseInsensitiveCompare(loved) == .orderedSame }) {
                return loved
            }
        }
        return nil
    }

    private static func onHandPhrase(_ recipe: Recipe) -> String? {
        let items = recipe.usesOnHand
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        guard !items.isEmpty else { return nil }
        let listed = Array(items.prefix(2))
        let phrase = listed.count == 1 ? listed[0] : "\(listed[0]) and \(listed[1])"
        return "it uses the \(phrase) you already have"
    }

    private static func learnedCuisine(in recipe: Recipe, lovedTags: [String], excluding cuisines: [String]) -> String? {
        for tag in recipe.tags {
            let matchesLoved = lovedTags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
            let alreadyCited = cuisines.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
            if matchesLoved && !alreadyCited { return tag }
        }
        return nil
    }

    /// If the recipe is tagged with a diet the cook keeps, name it.
    private static func dietFit(_ recipe: Recipe, profile: TasteProfile) -> String? {
        guard !profile.diets.isEmpty else { return nil }
        for diet in profile.diets {
            let title = diet.title
            if recipe.tags.contains(where: { $0.caseInsensitiveCompare(title) == .orderedSame }) {
                return title
            }
        }
        return nil
    }

    private static func quickPhrase(_ recipe: Recipe, profile: TasteProfile) -> String? {
        let total = recipe.totalMinutes
        guard total > 0 else { return nil }
        let ceiling = profile.maxCookMinutes > 0 ? min(profile.maxCookMinutes, 30) : 30
        guard total <= ceiling else { return nil }
        return "it’s ready in about \(total) min"
    }

    private static func spiceMatch(_ recipe: Recipe, profile: TasteProfile) -> Bool {
        guard profile.spiceLevel == .hot || profile.spiceLevel == .fiery else { return false }
        let heatWords = ["spicy", "hot", "fiery", "chili", "chilli"]
        return recipe.tags.contains { tag in
            heatWords.contains { tag.localizedCaseInsensitiveContains($0) }
        }
    }
}
