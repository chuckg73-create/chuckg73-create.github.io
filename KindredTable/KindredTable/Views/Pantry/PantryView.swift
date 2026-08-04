import SwiftUI

/// The editable ingredient list, grouped by category. Add by hand, edit details,
/// swipe to delete, then jump to recipe suggestions.
struct PantryView: View {
    @Environment(PantryStore.self) private var pantry
    var goToRecipes: () -> Void

    @State private var activeSheet: ActiveSheet?
    @State private var search = ""

    /// A single sheet slot. Using one `.sheet` avoids the SwiftUI conflict that
    /// arises when two `.sheet` modifiers are attached to the same view.
    private enum ActiveSheet: Identifiable {
        case add
        case edit(Ingredient)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let ingredient): return ingredient.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                if pantry.isEmpty {
                    EmptyState(
                        systemImage: "basket",
                        title: "Your pantry is empty",
                        message: "Snap a photo on the Capture tab, or add ingredients by hand to get started.",
                        actionTitle: "Add ingredient",
                        action: { activeSheet = .add }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .add } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    IngredientEditor(ingredient: nil) { pantry.add($0) }
                case .edit(let item):
                    IngredientEditor(ingredient: item) { pantry.update($0) }
                }
            }
        }
    }

    private var filteredGroups: [(category: IngredientCategory, items: [Ingredient])] {
        guard !search.isEmpty else { return pantry.grouped }
        return pantry.grouped.compactMap { group in
            let items = group.items.filter { $0.name.localizedCaseInsensitiveContains(search) }
            return items.isEmpty ? nil : (group.category, items)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            List {
                ForEach(filteredGroups, id: \.category) { group in
                    Section {
                        ForEach(group.items) { item in
                            IngredientRow(ingredient: item)
                                .contentShape(Rectangle())
                                .onTapGesture { activeSheet = .edit(item) }
                                .listRowBackground(KindredTheme.card)
                        }
                        .onDelete { offsets in
                            offsets.map { group.items[$0] }.forEach { pantry.remove($0) }
                        }
                    } header: {
                        Label("\(group.category.title) · \(group.items.count)", systemImage: group.category.systemImage)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $search, prompt: "Search ingredients")

            footer
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            KindredButton(title: "Find recipes for these", systemImage: "sparkles", action: goToRecipes)
            Text("\(pantry.ingredients.count) ingredients on hand")
                .font(.caption).foregroundStyle(KindredTheme.faint)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

/// A single row in the pantry list.
struct IngredientRow: View {
    var ingredient: Ingredient

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ingredient.category.systemImage)
                .foregroundStyle(KindredTheme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name).foregroundStyle(KindredTheme.text)
                if let q = ingredient.quantity, !q.isEmpty {
                    Text(q).font(.caption).foregroundStyle(KindredTheme.faint)
                }
            }
            Spacer()
            if ingredient.isAutoDetected {
                Image(systemName: "camera.viewfinder")
                    .font(.caption)
                    .foregroundStyle(KindredTheme.faint)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PantryView(goToRecipes: {})
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(ProfileStore(seed: .starter))
        .preferredColorScheme(.dark)
}
