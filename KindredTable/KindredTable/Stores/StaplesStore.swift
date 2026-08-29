import Foundation
import Observation

/// The staples a cook always keeps on hand — salt, oil, butter, flour — so they
/// never clutter the shopping list. Recipes treat these as already-available, and
/// the recipe prompt is told to keep them off the "to buy" list.
///
/// Seeded with sensible defaults on first run; fully editable in "Your taste".
@Observable
final class StaplesStore {

    private(set) var names: [String]

    private let fileName = "pantry_staples.json"

    /// Conservative defaults — things nearly every kitchen has and no one shops
    /// for by recipe. "Black pepper" (not "pepper") so bell/chili peppers still count.
    static let defaults = ["Salt", "Black pepper", "Olive oil", "Vegetable oil",
                           "Butter", "Sugar", "All-purpose flour", "Water"]

    init(seed: [String]? = nil) {
        if let loaded = LocalStore.load([String].self, from: fileName) {
            names = loaded                      // returning cook (may be empty by choice)
        } else {
            names = seed ?? Self.defaults       // first run seeds the defaults
            persist()
        }
    }

    /// Whether an ingredient name is covered by a staple (fuzzy: "kosher salt",
    /// "extra-virgin olive oil", "unsalted butter" all match).
    func covers(_ ingredientName: String) -> Bool {
        let item = ingredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard item.count >= 2 else { return false }
        return names.contains { staple in
            item.localizedCaseInsensitiveContains(staple)
                || staple.localizedCaseInsensitiveContains(item)
        }
    }

    func add(_ name: String) {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !names.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        names.append(value)
        persist()
    }

    func remove(_ name: String) {
        names.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        persist()
    }

    var isEmpty: Bool { names.isEmpty }

    /// A prompt block telling the model to treat staples as on-hand.
    func promptLine() -> String? {
        guard !names.isEmpty else { return nil }
        return "PANTRY STAPLES the cook always has (treat as available, mark haveIt=true, and NEVER put on the shopping list): \(names.joined(separator: ", "))."
    }

    private func persist() { LocalStore.save(names, to: fileName) }
}
