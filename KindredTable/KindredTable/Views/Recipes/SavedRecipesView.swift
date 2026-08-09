import SwiftUI

/// The family cookbook: recipes you've saved from the app plus your own recipes
/// photographed in — all in one place, all scalable to any number of servings.
struct CookbookView: View {
    @Environment(SavedRecipeStore.self) private var cookbook
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                if cookbook.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            addRecipeButton
                            if !cookbook.imported.isEmpty {
                                section(title: "Your recipes", icon: "heart.text.square.fill",
                                        recipes: cookbook.imported)
                            }
                            if !cookbook.fromApp.isEmpty {
                                section(title: "From the app", icon: "sparkles",
                                        recipes: cookbook.fromApp)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Cookbook")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() } }
            .sheet(isPresented: $showImport) { CookbookImportView() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            EmptyState(
                systemImage: "books.vertical",
                title: "Start your cookbook",
                message: "Save recipes the app finds, or add your own family recipes from a photo. Everything you keep lives here — and scales to any number of servings."
            )
            KindredButton(title: "Add a recipe from a photo", systemImage: "camera.fill") {
                showImport = true
            }
            .padding(.horizontal, 40)
        }
    }

    private var addRecipeButton: some View {
        Button { showImport = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add your own recipe").font(.subheadline.weight(.semibold))
                        .foregroundStyle(KindredTheme.text)
                    Text("Photograph Mom's card or a clipping").font(.caption)
                        .foregroundStyle(KindredTheme.subtext)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(KindredTheme.faint)
            }
            .padding(14)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KindredTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func section(title: String, icon: String, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.caption).foregroundStyle(KindredTheme.accent)
                SectionHeader(label: title)
                Spacer()
                Text("\(recipes.count)").font(.caption).foregroundStyle(KindredTheme.faint)
            }
            ForEach(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    RecipeCard(
                        recipe: recipe,
                        isSaved: true,
                        onSave: { cookbook.remove(recipe) }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    CookbookView()
        .environment(SavedRecipeStore(seed: SampleData.recipes))
        .environment(ProfileStore(seed: .starter))
        .preferredColorScheme(.dark)
}
