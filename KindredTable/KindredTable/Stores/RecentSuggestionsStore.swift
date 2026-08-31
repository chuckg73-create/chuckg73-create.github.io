import Foundation
import Observation

/// Remembers the dishes recently suggested to the cook so the recipe engine can
/// avoid repeating them — the fix for "I keep getting the same recipes." Rolling
/// window: recent enough to avoid déjà-vu, short enough that good ideas come back
/// around eventually.
@Observable
final class RecentSuggestionsStore {

    private(set) var titles: [String] = []   // most-recent first

    private let fileName = "recent_suggestions.json"
    private let limit = 40

    init(seed: [String]? = nil) {
        titles = seed ?? LocalStore.load([String].self, from: fileName) ?? []
    }

    /// Record freshly-shown recipes (moves repeats to the front, trims the tail).
    func record(_ recipes: [Recipe]) {
        for recipe in recipes {
            let title = recipe.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            titles.removeAll { $0.caseInsensitiveCompare(title) == .orderedSame }
            titles.insert(title, at: 0)
        }
        if titles.count > limit { titles = Array(titles.prefix(limit)) }
        persist()
    }

    /// A prompt block telling the engine to avoid recent repeats and diversify,
    /// or nil when there's nothing recent yet.
    func avoidBlock(limit: Int = 18) -> String? {
        let recent = Array(titles.prefix(limit))
        guard !recent.isEmpty else { return nil }
        return "VARIETY — you've recently suggested these to this cook; do NOT repeat them or close variations. Bring genuinely different ideas, varying the cuisine, protein and cooking method: \(recent.joined(separator: "; "))."
    }

    func clear() {
        titles = []
        persist()
    }

    private func persist() { LocalStore.save(titles, to: fileName) }
}
