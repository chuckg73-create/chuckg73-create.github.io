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
    /// True once the user explicitly changes the category, so auto-categorization
    /// stops overriding their choice.
    @State private var userPickedCategory: Bool

    init(ingredient: Ingredient?, onSave: @escaping (Ingredient) -> Void) {
        self.ingredient = ingredient
        self.onSave = onSave
        _name = State(initialValue: ingredient?.name ?? "")
        _category = State(initialValue: ingredient?.category ?? .other)
        _quantity = State(initialValue: ingredient?.quantity ?? "")
        // For an existing ingredient, respect its saved category as-is.
        _userPickedCategory = State(initialValue: ingredient != nil)
    }

    /// Picker binding that records a manual category choice.
    private var categoryBinding: Binding<IngredientCategory> {
        Binding(
            get: { category },
            set: { newValue in
                category = newValue
                userPickedCategory = true
            }
        )
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
                            .autocorrectionDisabled()
                        TextField("Quantity (optional)", text: $quantity)
                    }
                    .listRowBackground(KindredTheme.card)

                    if !suggestions.isEmpty {
                        Section("Suggestions") {
                            ForEach(suggestions, id: \.name) { suggestion in
                                Button {
                                    apply(suggestion)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: suggestion.category.systemImage)
                                            .foregroundStyle(KindredTheme.accent)
                                            .frame(width: 24)
                                        Text(suggestion.name)
                                            .foregroundStyle(KindredTheme.text)
                                        Spacer()
                                        Text(suggestion.category.title)
                                            .font(.caption)
                                            .foregroundStyle(KindredTheme.faint)
                                    }
                                }
                            }
                        }
                        .listRowBackground(KindredTheme.card)
                    }

                    Section("Category") {
                        Picker("Category", selection: categoryBinding) {
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
            .onChange(of: name) { _, newName in
                // Auto-file the item as they type, until they pick a category.
                guard !userPickedCategory else { return }
                let inferred = FoodVocabulary.categorize(newName)
                if inferred != .other { category = inferred }
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

    /// Live type-ahead matches for what's been typed so far.
    private var suggestions: [FoodVocabulary.Match] {
        FoodVocabulary.suggestions(for: name)
    }

    /// Fill in a tapped suggestion — name and its category. Treated as an
    /// explicit category choice so later typing won't override it.
    private func apply(_ suggestion: FoodVocabulary.Match) {
        userPickedCategory = true
        category = suggestion.category
        name = suggestion.name
    }

    private func save() {
        var result = ingredient ?? Ingredient(name: name)
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Final safety net: if it's still uncategorized, infer from the name.
        if !userPickedCategory, category == .other {
            category = FoodVocabulary.categorize(result.name)
        }
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
