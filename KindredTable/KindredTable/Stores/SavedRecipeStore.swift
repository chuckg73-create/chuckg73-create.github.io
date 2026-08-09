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

    /// Add a recipe to the cookbook (used for photo imports). No-ops if already
    /// present by id.
    func add(_ recipe: Recipe) {
        guard !saved.contains(where: { $0.id == recipe.id }) else { return }
        saved.insert(recipe, at: 0)
        persist()
    }

    /// Replace an existing recipe in place (e.g. after editing an import's
    /// attribution), keeping its position.
    func update(_ recipe: Recipe) {
        guard let idx = saved.firstIndex(where: { $0.id == recipe.id }) else { return }
        saved[idx] = recipe
        persist()
    }

    /// Recipes the cook photographed in, newest first.
    var imported: [Recipe] { saved.filter { $0.source.isImported } }
    /// Recipes matched/made by the app.
    var fromApp: [Recipe] { saved.filter { !$0.source.isImported } }

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
