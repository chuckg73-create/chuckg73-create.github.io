import SwiftUI
import UniformTypeIdentifiers

/// The family cookbook: recipes you've saved from the app plus your own recipes
/// photographed in — all in one place, all scalable to any number of servings.
struct CookbookView: View {
    @Environment(SavedRecipeStore.self) private var cookbook
    @State private var query = ""
    @State private var showFileImporter = false

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileToolbarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { presentExportSheet() } label: {
                            Label("Export My Cookbook", systemImage: "square.and.arrow.up")
                        }
                        Button { showFileImporter = true } label: {
                            Label("Import Cookbook From File", systemImage: "tray.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(KindredTheme.accent)
                    }
                    .accessibilityLabel("Cookbook sharing")
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.kindredCookbook]) { result in
                if case .success(let url) = result { presentImportSheet(url: url) }
            }
        }
    }

    // MARK: - UIKit-backed presentation

    // SwiftUI's .sheet mechanism fails after app lifecycle transitions on iOS 26's
    // redesigned TabView — re-renders from SavedRecipeStore updates invalidate the
    // sheet presenter regardless of where in the hierarchy the .sheet modifier lives.
    // UIKit's present(_:animated:) is lifecycle-stable and bypasses this entirely.

    private func presentAddRecipeSheet() {
        let root = CookbookImportView().environment(cookbook)
        presentUIKit(UIHostingController(rootView: root))
    }

    private func presentExportSheet() {
        let root = ExportCookbookSheet().environment(cookbook)
        presentUIKit(UIHostingController(rootView: root))
    }

    private func presentImportSheet(url: URL) {
        let root = CookbookPackageImportView(fileURL: url).environment(cookbook)
        presentUIKit(UIHostingController(rootView: root))
    }

    private func presentUIKit(_ vc: UIViewController) {
        vc.modalPresentationStyle = .pageSheet
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(vc, animated: true)
    }

    // MARK: - Subviews

    private var searchResultsSection: some View {
        let results = cookbook.saved.filter { Self.matches($0, trimmedQuery) }
        return Group {
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(KindredTheme.faint)
                    Text("No recipes match \"\(trimmedQuery)\"")
                        .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                section(title: "\(results.count) result\(results.count == 1 ? "" : "s")",
                        icon: "magnifyingglass", recipes: results)
            }
        }
    }

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
                presentAddRecipeSheet()
            }
            .padding(.horizontal, 40)
            Button { showFileImporter = true } label: {
                Label("Import a cookbook someone shared with you", systemImage: "tray.and.arrow.down")
            }
            .font(.subheadline).foregroundStyle(KindredTheme.accent)
        }
    }

    private var addRecipeButton: some View {
        Button { presentAddRecipeSheet() } label: {
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
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

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
                    Text("\"\(recipe.story)\"")
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

// MARK: - Export whole cookbook

struct ExportCookbookSheet: View {
    @Environment(SavedRecipeStore.self) private var cookbook
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isBuilding = false
    @State private var exportedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up.on.square.fill")
                                .font(.system(size: 40)).foregroundStyle(KindredTheme.accent)
                            Text("Export your cookbook")
                                .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                            Text("Every recipe you've saved, with your photos, in one file you can hand to family — AirDrop, Messages, Mail, or save to Files.")
                                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                                .multilineTextAlignment(.center)
                        }

                        KindredCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("COOKBOOK NAME")
                                    .font(.caption2.weight(.semibold)).foregroundStyle(KindredTheme.faint)
                                    .tracking(0.5)
                                TextField("e.g. Mom's Recipes", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .foregroundStyle(KindredTheme.text)
                            }
                        }

                        Text("\(cookbook.saved.count) recipe\(cookbook.saved.count == 1 ? "" : "s") will be included.")
                            .font(.caption).foregroundStyle(KindredTheme.faint)

                        if let errorMessage {
                            Text(errorMessage).font(.caption).foregroundStyle(KindredTheme.amber)
                        }

                        if let exportedURL {
                            ShareLink(item: exportedURL) {
                                Label("Share the cookbook file", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(KindredTheme.accent)
                        } else {
                            KindredButton(title: "Build cookbook file", systemImage: "archivebox.fill",
                                          isLoading: isBuilding) {
                                build()
                            }
                            .disabled(isBuilding || cookbook.isEmpty)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }

    private func build() {
        let recipes = cookbook.saved
        let cookbookName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = cookbookName.isEmpty ? "My Cookbook" : cookbookName
        isBuilding = true
        errorMessage = nil
        Task.detached {
            do {
                let url = try CookbookPackageService.export(recipes: recipes, cookbookName: resolvedName)
                await MainActor.run {
                    exportedURL = url
                    isBuilding = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't build the cookbook file. Try again."
                    isBuilding = false
                }
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
