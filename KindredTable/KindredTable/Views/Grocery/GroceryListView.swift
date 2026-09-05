import SwiftUI
import UIKit

/// The shopping list: add items by hand (auto-categorized), check them off as
/// you shop, and move what you bought straight into your On Hand list.
struct GroceryListView: View {
    @Environment(GroceryStore.self) private var grocery
    @Environment(PantryStore.self) private var pantry
    @Environment(\.openURL) private var openURL

    @State private var newItem = ""
    @State private var showShopOptions = false

    /// Retailers we can hand the list off to.
    private enum Store {
        case instacart, walmart
        var url: URL {
            switch self {
            case .instacart: return URL(string: "https://www.instacart.com/store")!
            case .walmart: return URL(string: "https://www.walmart.com/grocery")!
            }
        }
    }

    /// Unchecked items (what you still need), falling back to everything.
    private var shoppableItems: [GroceryItem] {
        let unchecked = grocery.items.filter { !$0.isChecked }
        return unchecked.isEmpty ? grocery.items : unchecked
    }

    /// Aisle-grouped plain text — nice to hand a partner or paste into a store.
    private var listText: String {
        var lines: [String] = ["🛒 Grocery list · KindredTable", ""]
        for group in grocery.grouped {
            let items = group.items.filter { !$0.isChecked }
            guard !items.isEmpty else { continue }
            lines.append(group.category.title.uppercased())
            for item in items { lines.append("• \(item.name)") }
            lines.append("")
        }
        let body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        // Fall back to a flat list if nothing is unchecked.
        return body.contains("•") ? body : shoppableItems.map { "• \($0.name)" }.joined(separator: "\n")
    }

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
            .safeAreaInset(edge: .bottom) {
                if !grocery.isEmpty {
                    shopBar
                }
            }
            .confirmationDialog("Shop this list", isPresented: $showShopOptions, titleVisibility: .visible) {
                Button("Open Instacart") { shop(.instacart) }
                Button("Open Walmart") { shop(.walmart) }
                Button("Copy list") { UIPasteboard.general.string = listText }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your list is copied to the clipboard so you can paste-search in the store.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() }
                if !grocery.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: listText) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Share list")
                    }
                }
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
                        .accessibilityLabel("Checked-item actions")
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

    private var hasUnshopped: Bool { grocery.items.contains { !$0.isChecked } }

    private var shopBar: some View {
        VStack(spacing: 4) {
            KindredButton(title: hasUnshopped ? "Shop this list" : "Nothing left to shop",
                          systemImage: hasUnshopped ? "bag.fill" : "checkmark.circle.fill") {
                showShopOptions = true
            }
            .disabled(!hasUnshopped)
            .opacity(hasUnshopped ? 1 : 0.5)
            Text(hasUnshopped ? "Hands off to Instacart or Walmart" : "Everything's checked off")
                .font(.caption2).foregroundStyle(KindredTheme.faint)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
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
    }

    /// Copy the list and hand off to a retailer's app/site.
    private func shop(_ store: Store) {
        UIPasteboard.general.string = listText
        openURL(store.url)
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
