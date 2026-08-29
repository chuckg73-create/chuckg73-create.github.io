import SwiftUI

/// Edit a recipe — fix an OCR mis-read on an imported card, tweak amounts, or
/// reword a step. Returns the edited recipe via `onSave`.
struct RecipeEditView: View {
    @State private var draft: Recipe
    let onSave: (Recipe) -> Void
    @Environment(\.dismiss) private var dismiss

    init(recipe: Recipe, onSave: @escaping (Recipe) -> Void) {
        _draft = State(initialValue: recipe)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                Form {
                    Section("Details") {
                        TextField("Recipe name", text: $draft.title)
                            .textInputAutocapitalization(.words)
                        if draft.source.isImported {
                            TextField("Whose recipe? (e.g. Mom)", text: $draft.sourceNote)
                                .textInputAutocapitalization(.words)
                            TextField("A memory (e.g. Mom made this every Christmas)", text: $draft.story, axis: .vertical)
                                .lineLimit(1...3)
                        }
                        Stepper("Serves \(draft.servings)", value: $draft.servings, in: 1...24)
                        TextField("One-line summary", text: $draft.summary, axis: .vertical)
                            .lineLimit(1...3)
                    }
                    .listRowBackground(KindredTheme.card)

                    Section {
                        ForEach($draft.ingredients) { $ing in
                            HStack(spacing: 8) {
                                TextField("Amount", text: $ing.amount)
                                    .frame(width: 110)
                                    .foregroundStyle(KindredTheme.text)
                                Divider().overlay(KindredTheme.hairline)
                                TextField("Ingredient", text: $ing.name)
                                    .foregroundStyle(KindredTheme.subtext)
                            }
                        }
                        .onDelete { draft.ingredients.remove(atOffsets: $0) }
                        .onMove { draft.ingredients.move(fromOffsets: $0, toOffset: $1) }
                        Button {
                            draft.ingredients.append(RecipeIngredient(name: "", amount: "", haveIt: false))
                        } label: {
                            Label("Add ingredient", systemImage: "plus.circle")
                        }
                    } header: {
                        Text("Ingredients")
                    }
                    .listRowBackground(KindredTheme.card)

                    Section {
                        ForEach(draft.steps.indices, id: \.self) { i in
                            TextField("Step \(i + 1)", text: $draft.steps[i], axis: .vertical)
                                .lineLimit(1...6)
                        }
                        .onDelete { draft.steps.remove(atOffsets: $0) }
                        .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
                        Button {
                            draft.steps.append("")
                        } label: {
                            Label("Add step", systemImage: "plus.circle")
                        }
                    } header: {
                        Text("Method")
                    }
                    .listRowBackground(KindredTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }

    private func save() {
        // Drop blank ingredients/steps left behind.
        draft.ingredients.removeAll { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        draft.steps = draft.steps.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        draft.title = draft.title.trimmingCharacters(in: .whitespaces)
        onSave(draft)
        dismiss()
    }
}
