import SwiftUI

/// Top-level container: onboarding on first launch, then the main tab bar.
struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        Group {
            if profileStore.hasOnboarded {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

/// The four core surfaces: capture, pantry, recipe feed, and saved.
struct RootTabView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(GroceryStore.self) private var grocery

    @State private var selection: Tab = .capture

    enum Tab: Hashable { case capture, pantry, recipes, saved, grocery }

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

            SavedRecipesView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .badge(saved.saved.count)
                .tag(Tab.saved)

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
        .preferredColorScheme(.dark)
}
