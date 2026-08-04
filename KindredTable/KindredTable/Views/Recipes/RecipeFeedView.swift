import SwiftUI

/// The daily meal suggestions feed. Generates recipes from the current pantry +
/// taste profile via the Gemini service, with save-for-later on each card.
struct RecipeFeedView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(SavedRecipeStore.self) private var saved

    @State private var model = RecipeFeedModel()

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                content
            }
            .navigationTitle("Today's ideas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh(ingredients: pantry.ingredients, profile: profileStore.profile) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoading || pantry.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() }
            }
            .task {
                await model.loadIfNeeded(ingredients: pantry.ingredients, profile: profileStore.profile)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if pantry.isEmpty {
            EmptyState(
                systemImage: "sparkles",
                title: "Add ingredients first",
                message: "Once your pantry has a few items, KindredTable will suggest meals you can make right now."
            )
        } else {
            switch model.phase {
            case .idle, .loading:
                loadingState
            case .failed(let message):
                EmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't load ideas",
                    message: message,
                    actionTitle: "Try again",
                    action: { Task { await model.refresh(ingredients: pantry.ingredients, profile: profileStore.profile) } }
                )
            case .loaded(let recipes):
                feed(recipes)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text("Matching recipes to your pantry…")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func feed(_ recipes: [Recipe]) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if model.usingSamples { sampleBanner }
                ForEach(recipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        RecipeCard(
                            recipe: recipe,
                            isSaved: saved.isSaved(recipe),
                            onSave: { saved.toggle(recipe) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .refreshable {
            await model.refresh(ingredients: pantry.ingredients, profile: profileStore.profile)
        }
    }

    private var sampleBanner: some View {
        Label(
            "Showing sample ideas — add a Gemini API key to get suggestions tailored to your exact pantry.",
            systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(KindredTheme.amber)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KindredTheme.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    RecipeFeedView()
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(ProfileStore(seed: .starter))
        .environment(SavedRecipeStore())
        .preferredColorScheme(.dark)
}
