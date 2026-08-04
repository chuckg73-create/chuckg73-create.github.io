import Foundation
import Observation

/// Save-for-later store for recipes the user wants to keep.
@Observable
final class SavedRecipeStore {

    private(set) var saved: [Recipe] = []

    private let fileName = "saved_recipes.json"

    init(seed: [Recipe]? = nil) {
        if let seed {
            saved = seed
        } else {
            saved = LocalStore.load([Recipe].self, from: fileName) ?? []
        }
    }

    var isEmpty: Bool { saved.isEmpty }

    func isSaved(_ recipe: Recipe) -> Bool {
        saved.contains { $0.id == recipe.id || $0.title == recipe.title }
    }

    func toggle(_ recipe: Recipe) {
        if isSaved(recipe) {
            remove(recipe)
        } else {
            saved.insert(recipe, at: 0)
            persist()
        }
    }

    func remove(_ recipe: Recipe) {
        saved.removeAll { $0.id == recipe.id || $0.title == recipe.title }
        persist()
    }

    func remove(at offsets: IndexSet) {
        saved.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        LocalStore.save(saved, to: fileName)
    }
}
