import Foundation
import Observation

/// The shopping list, persisted locally.
@Observable
final class GroceryStore {

    private(set) var items: [GroceryItem] = []

    private let fileName = "grocery.json"

    init(seed: [GroceryItem]? = nil) {
        if let seed {
            items = seed
        } else {
            items = LocalStore.load([GroceryItem].self, from: fileName) ?? []
        }
    }

    var isEmpty: Bool { items.isEmpty }
    var checkedCount: Int { items.lazy.filter(\.isChecked).count }

    /// Items grouped by grocery aisle, unchecked first within each group.
    var grouped: [(category: IngredientCategory, items: [GroceryItem])] {
        Dictionary(grouping: items, by: { $0.category })
            .map { key, value in
                (category: key, items: value.sorted {
                    ($0.isChecked ? 1 : 0, $0.name) < ($1.isChecked ? 1 : 0, $1.name)
                })
            }
            .sorted { $0.category.sortRank < $1.category.sortRank }
    }

    var checkedItems: [GroceryItem] { items.filter(\.isChecked) }

    // MARK: Mutations

    /// Add a single item, skipping case-insensitive duplicates. Returns whether
    /// it was newly added.
    @discardableResult
    func add(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !items.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return false }
        items.append(GroceryItem(name: trimmed))
        persist()
        return true
    }

    /// Add several names at once; returns how many were newly added.
    @discardableResult
    func addMany(_ names: [String]) -> Int {
        var added = 0
        for name in names where add(name) { added += 1 }
        return added
    }

    func toggle(_ item: GroceryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
        persist()
    }

    func remove(_ item: GroceryItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func removeChecked() {
        items.removeAll(where: { $0.isChecked })
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    private func persist() {
        LocalStore.save(items, to: fileName)
    }
}
