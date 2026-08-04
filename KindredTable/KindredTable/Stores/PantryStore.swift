import Foundation
import Observation

/// Owns the user's editable ingredient list, persisted locally.
@Observable
final class PantryStore {

    private(set) var ingredients: [Ingredient] = []

    private let fileName = "pantry.json"

    init(seed: [Ingredient]? = nil) {
        if let seed {
            ingredients = seed
        } else {
            ingredients = LocalStore.load([Ingredient].self, from: fileName) ?? []
        }
    }

    var isEmpty: Bool { ingredients.isEmpty }

    /// Ingredients grouped by category, sorted for the pantry list.
    var grouped: [(category: IngredientCategory, items: [Ingredient])] {
        Dictionary(grouping: ingredients, by: { $0.category })
            .map { (category: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.category.sortRank < $1.category.sortRank }
    }

    // MARK: Mutations

    func add(_ ingredient: Ingredient) {
        // Avoid duplicate names (case-insensitive); keep the higher confidence.
        if let index = ingredients.firstIndex(where: { $0.name.lowercased() == ingredient.name.lowercased() }) {
            let existing = ingredients[index]
            if (ingredient.confidence ?? 0) > (existing.confidence ?? 0) {
                ingredients[index].confidence = ingredient.confidence
            }
            if ingredients[index].quantity == nil, let q = ingredient.quantity {
                ingredients[index].quantity = q
            }
        } else {
            ingredients.append(ingredient)
        }
        persist()
    }

    /// Merge a batch of recognised ingredients, returning how many were new.
    @discardableResult
    func merge(_ batch: [Ingredient]) -> Int {
        let before = ingredients.count
        for item in batch { add(item) }
        return ingredients.count - before
    }

    func update(_ ingredient: Ingredient) {
        guard let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return }
        ingredients[index] = ingredient
        persist()
    }

    func remove(_ ingredient: Ingredient) {
        ingredients.removeAll { $0.id == ingredient.id }
        persist()
    }

    func remove(at offsets: IndexSet, within category: IngredientCategory) {
        let items = grouped.first(where: { $0.category == category })?.items ?? []
        let ids = offsets.map { items[$0].id }
        ingredients.removeAll { ids.contains($0.id) }
        persist()
    }

    func clear() {
        ingredients.removeAll()
        persist()
    }

    private func persist() {
        LocalStore.save(ingredients, to: fileName)
    }
}
