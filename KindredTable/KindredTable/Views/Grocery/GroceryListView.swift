import SwiftUI

/// The shopping list: add items by hand (auto-categorized), check them off as
/// you shop, and move what you bought straight into your On Hand list.
struct GroceryListView: View {
    @Environment(GroceryStore.self) private var grocery
    @Environment(PantryStore.self) private var pantry

    @State private var newItem = ""
    @State private var justMoved = false

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                if grocery.isEmpty {
                    EmptyState(
                        systemImage: "cart",
                        title: "Your list is empty",
                        message: "Add items with the field above, or open a recipe and add its \u{201C}need to buy\u{201D} items in one tap."
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Grocery")
            .safeAreaInset(edge: .top) { addBar }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() }
                if grocery.checkedCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                moveCheckedToPantry()
                            } label: {
                                Label("Move checked to On Hand", systemImage: "arrow.right.circle")
                            }
                            Button(role: .destructive) {
                                grocery.removeChecked()
                            } label: {
                                Label("Clear checked items", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    private var content: some View {
        List {
            ForEach(grocery.grouped, id: \.category) { group in
                Section {
                    ForEach(group.items) { item in
                        row(item)
                    }
                    .onDelete { offsets in
                        offsets.map { group.items[$0] }.forEach { grocery.remove($0) }
                    }
                } header: {
                    Label("\(group.category.title) · \(group.items.count)", systemImage: group.category.systemImage)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill").foregroundStyle(KindredTheme.accent)
            TextField("Add an item", text: $newItem)
                .textInputAutocapitalization(.words)
                .onSubmit(add)
            if !newItem.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: add).fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func row(_ item: GroceryItem) -> some View {
        Button {
            grocery.toggle(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? KindredTheme.mint : KindredTheme.faint)
                Text(item.name)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? KindredTheme.faint : KindredTheme.text)
                Spacer()
                Image(systemName: item.category.systemImage)
                    .font(.caption)
                    .foregroundStyle(KindredTheme.faint)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(KindredTheme.card)
    }

    private func add() {
        grocery.add(newItem)
        newItem = ""
    }

    /// Move everything checked off into the On Hand list (you just bought it).
    private func moveCheckedToPantry() {
        for item in grocery.checkedItems {
            pantry.add(Ingredient(name: item.name, category: item.category))
        }
        grocery.removeChecked()
        justMoved = true
    }
}

#Preview {
    GroceryListView()
        .environment(GroceryStore(seed: [
            GroceryItem(name: "Milk"),
            GroceryItem(name: "Basil"),
            GroceryItem(name: "Chicken thighs"),
            GroceryItem(name: "Olive oil", isChecked: true),
        ]))
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(ProfileStore(seed: .starter))
        .preferredColorScheme(.dark)
}
