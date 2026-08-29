import Foundation
import Observation

/// Lightweight, per-tag taste steering from "More like this / Less like this"
/// taps on recipes the cook *hasn't necessarily made* — distinct from
/// `TasteFeedbackStore`, which records dishes they actually cooked and rated.
///
/// Each vote nudges the recipe's tags up or down; the net scores feed the recipe
/// prompt so the next batch visibly shifts toward what the cook asked for.
@Observable
final class TastePreferenceStore {

    /// Lowercased tag → net score (positive = show more, negative = show less).
    private(set) var scores: [String: Int] = [:]

    private let fileName = "taste_preferences.json"

    init(seed: [String: Int]? = nil) {
        scores = seed ?? LocalStore.load([String: Int].self, from: fileName) ?? [:]
    }

    /// Record a "more/less like this" vote across the recipe's descriptive tags.
    func vote(_ recipe: Recipe, up: Bool) {
        for tag in tags(of: recipe) {
            scores[tag.lowercased(), default: 0] += up ? 1 : -1
        }
        // Drop anything that's netted back to neutral to keep the profile tidy.
        scores = scores.filter { $0.value != 0 }
        persist()
    }

    /// The most representative tag of a recipe, for a friendly confirmation
    /// ("more Thai coming up").
    func headlineTag(of recipe: Recipe) -> String? { tags(of: recipe).first }

    var boosted: [String] {
        scores.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map(\.key)
    }
    var suppressed: [String] {
        scores.filter { $0.value < 0 }.sorted { $0.value < $1.value }.map(\.key)
    }
    var isEmpty: Bool { scores.isEmpty }

    func clear() {
        scores = [:]
        persist()
    }

    /// A steering block for the recipe prompt, or nil when nothing's been tuned.
    func promptLine(limit: Int = 6) -> String? {
        let up = Array(boosted.prefix(limit))
        let down = Array(suppressed.prefix(limit))
        guard !up.isEmpty || !down.isEmpty else { return nil }
        var lines = ["TASTE STEERING — the cook has tuned these preferences by hand:"]
        if !up.isEmpty { lines.append("- Favor dishes like: \(up.joined(separator: ", ")).") }
        if !down.isEmpty { lines.append("- Show fewer dishes like: \(down.joined(separator: ", ")).") }
        return lines.joined(separator: "\n")
    }

    /// Descriptive tags worth steering on (skip trivially short ones).
    private func tags(of recipe: Recipe) -> [String] {
        recipe.tags
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 3 }
    }

    private func persist() { LocalStore.save(scores, to: fileName) }
}
