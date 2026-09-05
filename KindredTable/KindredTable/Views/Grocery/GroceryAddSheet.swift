import SwiftUI

/// One-tap sheet to add a recipe's missing ingredients to the grocery list.
/// Appears automatically when the user saves a recipe that has items to buy.
struct GroceryAddSheet: View {
    var recipe: Recipe
    @Environment(GroceryStore.self) private var grocery
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String>

    init(recipe: Recipe) {
        self.recipe = recipe
        _selected = State(initialValue: Set(recipe.needsToBuy))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                VStack(spacing: 0) {
                    headerCard
                    List {
                        Section {
                            ForEach(recipe.needsToBuy, id: \.self) { item in
                                let on = selected.contains(item)
                                Button {
                                    if on { selected.remove(item) } else { selected.insert(item) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(on ? KindredTheme.accent : KindredTheme.faint)
                                        Text(item.capitalized)
                                            .foregroundStyle(KindredTheme.text)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(KindredTheme.card)
                            }
                        } header: {
                            Text("Ingredients to add")
                        }
                    }
                    .scrollContentBackground(.hidden)

                    footer
                }
            }
            .navigationTitle("Grocery list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                        .foregroundStyle(KindredTheme.subtext)
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "cart.badge.plus")
                .font(.title2).foregroundStyle(KindredTheme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Add missing ingredients?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KindredTheme.text)
                Text("\(recipe.needsToBuy.count) item\(recipe.needsToBuy.count == 1 ? "" : "s") needed for \(recipe.title)")
                    .font(.caption)
                    .foregroundStyle(KindredTheme.subtext)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(KindredTheme.card)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            KindredButton(
                title: selected.isEmpty ? "Nothing selected" : "Add \(selected.count) item\(selected.count == 1 ? "" : "s") to list",
                systemImage: "cart.fill"
            ) {
                grocery.addMany(Array(selected).sorted())
                dismiss()
            }
            .disabled(selected.isEmpty)

            Button("Skip") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(KindredTheme.subtext)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    GroceryAddSheet(recipe: SampleData.recipes[0])
        .environment(GroceryStore())
        .preferredColorScheme(.dark)
}
