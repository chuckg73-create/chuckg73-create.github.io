import Foundation

extension TasteProfile {
    /// Blend several people's profiles into one "cook for everyone" profile:
    /// combine what everyone loves, treat every person's dislikes and allergens
    /// as hard vetoes (nobody is served what they hate), and take the most
    /// accommodating of the rest — the mildest spice, simplest skill, and
    /// shortest max cook time — so a single meal works for the whole table,
    /// kids included. Equipment stays the host's (theirs is the kitchen cooking).
    static func blend(_ profiles: [TasteProfile]) -> TasteProfile {
        guard let host = profiles.first else { return .empty }
        guard profiles.count > 1 else { return host }

        let spiceOrder: [SpiceLevel] = [.mild, .medium, .hot, .fiery]
        let skillOrder: [CookingSkill] = [.beginner, .comfortable, .confident]

        var blended = host
        blended.diets = profiles.reduce(into: Set<Diet>()) { $0.formUnion($1.diets) }
        blended.lovedCuisines = unionPreservingOrder(profiles.map(\.lovedCuisines))
        blended.dislikedIngredients = unionPreservingOrder(profiles.map(\.dislikedIngredients))
        blended.allergens = unionPreservingOrder(profiles.map(\.allergens))
        blended.spiceLevel = profiles.map(\.spiceLevel).min { lhs, rhs in
            (spiceOrder.firstIndex(of: lhs) ?? 0) < (spiceOrder.firstIndex(of: rhs) ?? 0)
        } ?? host.spiceLevel
        blended.skill = profiles.map(\.skill).min { lhs, rhs in
            (skillOrder.firstIndex(of: lhs) ?? 0) < (skillOrder.firstIndex(of: rhs) ?? 0)
        } ?? host.skill
        blended.maxCookMinutes = profiles.map(\.maxCookMinutes).min() ?? host.maxCookMinutes

        // Nudge the model to please the whole group when more than one person.
        let groupNote = "Cooking for \(profiles.count) people together — the meal must work for everyone at the table (kid-friendly where relevant), and must not include anything in the avoid or allergen lists."
        blended.notes = host.notes.isEmpty ? groupNote : "\(host.notes)\n\(groupNote)"
        return blended
    }

    private static func unionPreservingOrder(_ arrays: [[String]]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for array in arrays {
            for value in array {
                let key = value.lowercased().trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(value)
            }
        }
        return out
    }
}
