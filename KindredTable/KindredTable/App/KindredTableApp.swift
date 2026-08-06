import SwiftUI

@main
struct KindredTableApp: App {

    @State private var pantry = PantryStore()
    @State private var saved = SavedRecipeStore()
    @State private var profileStore = ProfileStore()
    @State private var grocery = GroceryStore()
    @State private var household = HouseholdStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pantry)
                .environment(saved)
                .environment(profileStore)
                .environment(grocery)
                .environment(household)
                .preferredColorScheme(.dark)
                .tint(KindredTheme.accent)
        }
    }
}
