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

    /// Perishable-ish items the cook has had a while — names to prioritize so
    /// food doesn't go to waste. Skips shelf-stable spices/pantry staples.
    func useUpNames(olderThanDays days: Int = 3, limit: Int = 5, now: Date = Date()) -> [String] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let perishable: Set<IngredientCategory> = [.produce, .protein, .dairy, .frozen]
        return ingredients
            .filter { perishable.contains($0.category) && $0.addedAt <= cutoff }
            .sorted { $0.addedAt < $1.addedAt }
            .prefix(limit)
            .map(\.name)
    }

    /// Perishables at or past their freshness window — the cook should confirm
    /// they still have them (oldest first).
    func agingItems(now: Date = Date()) -> [Ingredient] {
        ingredients
            .filter { $0.freshness(now: now).needsAttention }
            .sorted { $0.addedAt < $1.addedAt }
    }

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

    /// The cook confirmed they still have this — reset its freshness clock.
    func refresh(_ ingredient: Ingredient, now: Date = Date()) {
        guard let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return }
        ingredients[index].addedAt = now
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
