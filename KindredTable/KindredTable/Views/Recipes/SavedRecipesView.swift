import SwiftUI

/// The save-for-later list.
struct SavedRecipesView: View {
    @Environment(SavedRecipeStore.self) private var saved

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                if saved.isEmpty {
                    EmptyState(
                        systemImage: "bookmark",
                        title: "Nothing saved yet",
                        message: "Tap the bookmark on any recipe to keep it here for later."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(saved.saved) { recipe in
                                NavigationLink {
                                    RecipeDetailView(recipe: recipe)
                                } label: {
                                    RecipeCard(
                                        recipe: recipe,
                                        isSaved: true,
                                        onSave: { saved.toggle(recipe) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Saved")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() } }
        }
    }
}

#Preview {
    SavedRecipesView()
        .environment(SavedRecipeStore(seed: SampleData.recipes))
        .environment(ProfileStore(seed: .starter))
        .preferredColorScheme(.dark)
}
