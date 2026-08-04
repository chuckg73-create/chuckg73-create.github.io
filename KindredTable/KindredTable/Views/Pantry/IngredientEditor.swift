import SwiftUI

/// Add or edit a single ingredient — name, category, and optional quantity.
struct IngredientEditor: View {
    /// nil = creating a new ingredient.
    var ingredient: Ingredient?
    var onSave: (Ingredient) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: IngredientCategory
    @State private var quantity: String

    init(ingredient: Ingredient?, onSave: @escaping (Ingredient) -> Void) {
        self.ingredient = ingredient
        self.onSave = onSave
        _name = State(initialValue: ingredient?.name ?? "")
        _category = State(initialValue: ingredient?.category ?? .other)
        _quantity = State(initialValue: ingredient?.quantity ?? "")
    }

    private var isEditing: Bool { ingredient != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                Form {
                    Section("Ingredient") {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                        TextField("Quantity (optional)", text: $quantity)
                    }
                    .listRowBackground(KindredTheme.card)

                    Section("Category") {
                        Picker("Category", selection: $category) {
                            ForEach(IngredientCategory.allCases) { cat in
                                Label(cat.title, systemImage: cat.systemImage).tag(cat)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    .listRowBackground(KindredTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit ingredient" : "Add ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        var result = ingredient ?? Ingredient(name: name)
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.category = category
        let trimmedQty = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        result.quantity = trimmedQty.isEmpty ? nil : trimmedQty
        onSave(result)
        dismiss()
    }
}

#Preview {
    IngredientEditor(ingredient: SampleData.ingredients[0], onSave: { _ in })
        .preferredColorScheme(.dark)
}
