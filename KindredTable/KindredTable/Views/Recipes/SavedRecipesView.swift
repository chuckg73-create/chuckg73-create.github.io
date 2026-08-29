import SwiftUI

/// The family cookbook: recipes you've saved from the app plus your own recipes
/// photographed in — all in one place, all scalable to any number of servings.
struct CookbookView: View {
    @Environment(SavedRecipeStore.self) private var cookbook
    @State private var showImport = false
    @State private var query = ""

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

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
                            if trimmedQuery.isEmpty {
                                if !cookbook.imported.isEmpty { familySection }
                                if !cookbook.fromApp.isEmpty {
                                    section(title: "From KindredTable", icon: "sparkles",
                                            recipes: cookbook.fromApp)
                                }
                            } else {
                                searchResultsSection
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Cookbook")
            .searchable(text: $query, prompt: "Search recipes & ingredients")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() } }
            .sheet(isPresented: $showImport) { CookbookImportView() }
        }
    }

    private var searchResultsSection: some View {
        let results = cookbook.saved.filter { Self.matches($0, trimmedQuery) }
        return Group {
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(KindredTheme.faint)
                    Text("No recipes match “\(trimmedQuery)”")
                        .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                section(title: "\(results.count) result\(results.count == 1 ? "" : "s")",
                        icon: "magnifyingglass", recipes: results)
            }
        }
    }

    /// Case-insensitive match across title, attribution, summary, tags and
    /// ingredient names.
    static func matches(_ r: Recipe, _ q: String) -> Bool {
        let n = q.lowercased()
        if r.title.lowercased().contains(n) { return true }
        if r.sourceNote.lowercased().contains(n) { return true }
        if r.story.lowercased().contains(n) { return true }
        if r.summary.lowercased().contains(n) { return true }
        if r.tags.contains(where: { $0.lowercased().contains(n) }) { return true }
        if r.ingredients.contains(where: { $0.name.lowercased().contains(n) }) { return true }
        return false
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

    /// The heart of the cookbook — family recipes shown as treasured cards with
    /// their attribution and memory front and center.
    private var familySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill").font(.caption).foregroundStyle(KindredTheme.coral)
                SectionHeader(label: "Family recipes")
                Spacer()
                Text("\(cookbook.imported.count)").font(.caption).foregroundStyle(KindredTheme.faint)
            }
            ForEach(cookbook.imported) { recipe in
                NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                    familyCard(recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func familyCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeHeroImage(recipe: recipe, height: 168)
            VStack(alignment: .leading, spacing: 8) {
                Label(recipe.sourceNote.isEmpty ? "Your recipe" : "From \(recipe.sourceNote)",
                      systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KindredTheme.coral)
                Text(recipe.title)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(KindredTheme.text)
                if !recipe.story.isEmpty {
                    Text("“\(recipe.story)”")
                        .font(.subheadline).italic()
                        .foregroundStyle(KindredTheme.subtext)
                        .lineLimit(2)
                }
                HStack(spacing: 14) {
                    Label("\(recipe.totalMinutes) min", systemImage: "clock")
                    Label("Serves \(recipe.servings)", systemImage: "person.2.fill")
                }
                .font(.caption).foregroundStyle(KindredTheme.faint)
            }
            .padding(16)
        }
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
            .stroke(KindredTheme.coral.opacity(0.28), lineWidth: 1))
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
