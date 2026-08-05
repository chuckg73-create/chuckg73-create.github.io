import Foundation

/// A single line on the shopping list.
struct GroceryItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var category: IngredientCategory
    var isChecked: Bool
    var addedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: IngredientCategory? = nil,
        isChecked: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmed
        // Auto-file into a grocery aisle if no category is supplied.
        self.category = category ?? FoodVocabulary.categorize(trimmed)
        self.isChecked = isChecked
        self.addedAt = addedAt
    }
}
