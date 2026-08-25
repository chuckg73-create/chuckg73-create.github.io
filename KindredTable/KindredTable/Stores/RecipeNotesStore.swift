import Foundation
import Observation

/// Personal notes the cook adds to a recipe ("used less salt", "kids loved it").
/// Keyed by recipe title, persisted on-device.
@Observable
final class RecipeNotesStore {

    private var notes: [String: String] = [:]
    private let fileName = "recipe_notes.json"

    init(seed: [String: String]? = nil) {
        notes = seed ?? LocalStore.load([String: String].self, from: fileName) ?? [:]
    }

    func note(for recipe: Recipe) -> String {
        notes[key(recipe.title)] ?? ""
    }

    func setNote(_ text: String, for recipe: Recipe) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let k = key(recipe.title)
        if trimmed.isEmpty { notes.removeValue(forKey: k) } else { notes[k] = trimmed }
        persist()
    }

    private func key(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persist() {
        LocalStore.save(notes, to: fileName)
    }
}
