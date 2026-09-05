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
                        title: "Nothing on hand yet",
                        message: "Snap a photo on the Home tab, or add ingredients by hand to get started.",
                        actionTitle: "Add ingredient",
                        action: { activeSheet = .add }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("On Hand")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .add } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add ingredient")
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
        if search.isEmpty {
            // Items surfaced in the "Check freshness" section are shown there
            // instead of duplicated in their category group.
            let agingIDs = Set(pantry.agingItems().map(\.id))
            return pantry.grouped.compactMap { group in
                let items = group.items.filter { !agingIDs.contains($0.id) }
                return items.isEmpty ? nil : (group.category, items)
            }
        }
        return pantry.grouped.compactMap { group in
            let items = group.items.filter { $0.name.localizedCaseInsensitiveContains(search) }
            return items.isEmpty ? nil : (group.category, items)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            List {
                if search.isEmpty { freshnessSection }
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

    /// Perishables at/near their freshness window — a new photo can't tell what
    /// you've used up, so this is where the cook keeps or clears them.
    @ViewBuilder private var freshnessSection: some View {
        let aging = pantry.agingItems()
        if !aging.isEmpty {
            Section {
                ForEach(aging) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: item.category.systemImage)
                                .foregroundStyle(freshnessColor(item)).frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).foregroundStyle(KindredTheme.text)
                                if let label = item.freshness().shortLabel {
                                    Text(label).font(.caption.weight(.medium))
                                        .foregroundStyle(freshnessColor(item))
                                }
                            }
                            Spacer()
                        }
                        HStack(spacing: 10) {
                            Button { pantry.refresh(item) } label: {
                                Label("Still have it", systemImage: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .foregroundStyle(KindredTheme.accent)
                                    .background(KindredTheme.accent.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button { withAnimation { pantry.remove(item) } } label: {
                                Label("Used it up", systemImage: "trash")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .foregroundStyle(KindredTheme.subtext)
                                    .background(KindredTheme.faint.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(KindredTheme.card)
                }
            } header: {
                Label("Check freshness · \(aging.count)", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(KindredTheme.amber)
            } footer: {
                Text("A new photo adds what's new but can't tell what you've used up. Keep these or clear them so suggestions stay accurate.")
            }
        }
    }

    private func freshnessColor(_ item: Ingredient) -> Color {
        if case .past = item.freshness() { return KindredTheme.coral }
        return KindredTheme.amber
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
            if let label = ingredient.freshness().shortLabel {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundStyle(badgeColor)
                    .background(badgeColor.opacity(0.15), in: Capsule())
            }
            if ingredient.isAutoDetected {
                Image(systemName: "camera.viewfinder")
                    .font(.caption)
                    .foregroundStyle(KindredTheme.faint)
            }
        }
        .padding(.vertical, 2)
    }

    private var badgeColor: Color {
        if case .past = ingredient.freshness() { return KindredTheme.coral }
        return KindredTheme.amber
    }
}

#Preview {
    PantryView(goToRecipes: {})
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(ProfileStore(seed: .starter))
        .preferredColorScheme(.dark)
}
