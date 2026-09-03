import SwiftUI

/// Top-level container: onboarding on first launch, then the main tab bar.
struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household

    @State private var importedName: String?
    @State private var incomingCookbookURL: URL?

    var body: some View {
        Group {
            if profileStore.hasOnboarded {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        .onOpenURL { url in
            if url.isFileURL, url.pathExtension.lowercased() == "kindredcookbook" {
                incomingCookbookURL = url
                return
            }
            guard let card = TasteCard.parse(url: url) else { return }
            household.add(card)
            importedName = card.name
        }
        .sheet(item: $incomingCookbookURL) { url in
            CookbookPackageImportView(fileURL: url)
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

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// The five core surfaces: capture, pantry, recipe feed, cookbook, and grocery.
///
/// Cookbook sheet state lives HERE, not inside CookbookView. Every recipe save
/// triggers a SavedRecipeStore update that re-renders CookbookView — if the sheet
/// state lived there, that re-render would silently kill the presenter after the
/// phone sleeps or after several recipes are added. Owning the state here means
/// CookbookView re-renders have zero effect on the sheet lifecycle.
struct RootTabView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(GroceryStore.self) private var grocery

    @State private var selection: Tab = .capture
    @State private var cookbookSheet: CookbookSheet?

    enum Tab: Hashable { case capture, pantry, recipes, cookbook, grocery }

    private enum CookbookSheet: Identifiable {
        case addFromPhoto
        case export
        case importPackage(URL)

        var id: String {
            switch self {
            case .addFromPhoto: return "addFromPhoto"
            case .export: return "export"
            case .importPackage(let url): return "importPackage-\(url.absoluteString)"
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            CaptureView(goToPantry: { selection = .pantry },
                        goToRecipes: { selection = .recipes },
                        goToCookbook: { selection = .cookbook })
                .tabItem { Label("Capture", systemImage: "camera.viewfinder") }
                .tag(Tab.capture)

            PantryView(goToRecipes: { selection = .recipes })
                .tabItem { Label("On Hand", systemImage: "list.bullet.rectangle.portrait") }
                .badge(pantry.ingredients.count)
                .tag(Tab.pantry)

            RecipeFeedView()
                .tabItem { Label("Recipes", systemImage: "fork.knife") }
                .tag(Tab.recipes)

            CookbookView(
                onAddRecipe: { cookbookSheet = .addFromPhoto },
                onExport: { cookbookSheet = .export },
                onImportPackage: { url in cookbookSheet = .importPackage(url) }
            )
            .tabItem { Label("Cookbook", systemImage: "books.vertical.fill") }
            .badge(saved.saved.count)
            .tag(Tab.cookbook)

            GroceryListView()
                .tabItem { Label("Grocery", systemImage: "cart.fill") }
                .badge(grocery.items.count)
                .tag(Tab.grocery)
        }
        // Sheet is on the TabView itself — completely outside CookbookView's
        // render cycle and insulated from SavedRecipeStore updates.
        .sheet(item: $cookbookSheet) { sheet in
            switch sheet {
            case .addFromPhoto: CookbookImportView()
            case .export: ExportCookbookSheet()
            case .importPackage(let url): CookbookPackageImportView(fileURL: url)
            }
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
        .environment(MealPlanStore())
        .environment(TasteFeedbackStore())
        .environment(RecipeNotesStore())
        .preferredColorScheme(.dark)
}
