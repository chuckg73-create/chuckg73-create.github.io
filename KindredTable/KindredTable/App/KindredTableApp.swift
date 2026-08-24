import SwiftUI

@main
struct KindredTableApp: App {

    @State private var pantry = PantryStore()
    @State private var saved = SavedRecipeStore()
    @State private var profileStore = ProfileStore()
    @State private var grocery = GroceryStore()
    @State private var household = HouseholdStore()
    @State private var mealPlan = MealPlanStore()
    @State private var feedback = TasteFeedbackStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pantry)
                .environment(saved)
                .environment(profileStore)
                .environment(grocery)
                .environment(household)
                .environment(mealPlan)
                .environment(feedback)
                .onAppear { mealPlan.prunePast() }
                .preferredColorScheme(.dark)
                .tint(KindredTheme.accent)
        }
    }
}
