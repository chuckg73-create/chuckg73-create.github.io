import SwiftUI

/// Top-level container: onboarding on first launch, then the main tab bar.
struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household

    @State private var importedName: String?

    var body: some View {
        Group {
            if profileStore.hasOnboarded {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        // A shared kindredkitchen://taste link (AirDrop, Messages, tapped link)
        // adds that person to your table.
        .onOpenURL { url in
            guard let card = TasteCard.parse(url: url) else { return }
            household.add(card)
            importedName = card.name
        }
        .alert("Added \(importedName ?? "")", isPresented: Binding(
            get: { importedName != nil }, set: { if !$0 { importedName = nil } }
        )) {
            Button("OK") { importedName = nil }
        } message: {
            Text("They're now at your table — recipes will blend their taste with yours.")
        }
    }
}

/// The five core surfaces: capture, pantry, recipe feed, cookbook, and grocery.
struct RootTabView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(GroceryStore.self) private var grocery

    @State private var selection: Tab = .capture

    enum Tab: Hashable { case capture, pantry, recipes, cookbook, grocery }

    var body: some View {
        TabView(selection: $selection) {
            CaptureView(goToPantry: { selection = .pantry })
                .tabItem { Label("Capture", systemImage: "camera.viewfinder") }
                .tag(Tab.capture)

            PantryView(goToRecipes: { selection = .recipes })
                .tabItem { Label("On Hand", systemImage: "list.bullet.rectangle.portrait") }
                .badge(pantry.ingredients.count)
                .tag(Tab.pantry)

            RecipeFeedView()
                .tabItem { Label("Recipes", systemImage: "fork.knife") }
                .tag(Tab.recipes)

            CookbookView()
                .tabItem { Label("Cookbook", systemImage: "books.vertical.fill") }
                .badge(saved.saved.count)
                .tag(Tab.cookbook)

            GroceryListView()
                .tabItem { Label("Grocery", systemImage: "cart.fill") }
                .badge(grocery.items.count)
                .tag(Tab.grocery)
        }
    }
}

#Preview {
    RootTabView()
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(SavedRecipeStore(seed: [SampleData.recipes[0]]))
        .environment(ProfileStore(seed: .starter))
        .environment(GroceryStore())
        .environment(HouseholdStore())
        .preferredColorScheme(.dark)
}
