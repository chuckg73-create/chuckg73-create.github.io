import SwiftUI

/// Paste any recipe URL and KindredTable extracts it into your cookbook.
struct URLImportView: View {
    @Environment(SavedRecipeStore.self) private var cookbook
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var imported: Recipe?
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        urlField
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption).foregroundStyle(KindredTheme.amber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        if let imported { previewCard(imported) }
                        if imported == nil { examples }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Import from URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { focused = true }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 44)).foregroundStyle(KindredTheme.accent)
            Text("Paste any recipe link")
                .font(.title3).fontWeight(.bold).foregroundStyle(KindredTheme.text)
            Text("NYT Cooking, Serious Eats, Food Network, AllRecipes — anything with a recipe on the page.")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
        }
    }

    private var urlField: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "link").foregroundStyle(KindredTheme.faint)
                TextField("https://...", text: $urlText)
                    .focused($focused)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { startImport() }
                if !urlText.isEmpty {
                    Button { urlText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(KindredTheme.faint)
                    }
                }
            }
            .padding(14)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))

            KindredButton(title: "Import recipe", systemImage: "arrow.down.circle.fill",
                          isLoading: isImporting) {
                startImport()
            }
            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
        }
    }

    private func previewCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(KindredTheme.mint).font(.title3)
                Text("Recipe found").font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.mint)
            }
            KindredCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(recipe.title)
                        .font(.headline).foregroundStyle(KindredTheme.text)
                    Text(recipe.summary)
                        .font(.caption).foregroundStyle(KindredTheme.subtext).lineLimit(3)
                    HStack(spacing: 16) {
                        Label("\(recipe.totalMinutes) min", systemImage: "clock")
                        Label("Serves \(recipe.servings)", systemImage: "person.2.fill")
                        Label("\(recipe.ingredients.count) ingredients", systemImage: "list.bullet")
                    }
                    .font(.caption2).foregroundStyle(KindredTheme.faint)
                }
            }
            KindredButton(title: "Add to Cookbook", systemImage: "books.vertical.fill") {
                cookbook.add(recipe)
                dismiss()
            }
            Button("Try a different URL") { imported = nil; urlText = "" }
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .frame(maxWidth: .infinity)
        }
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Works with")
                .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.faint).tracking(0.5)
            ForEach(["NYT Cooking", "Serious Eats", "Food Network",
                     "AllRecipes", "Bon Appetit", "Smitten Kitchen"], id: \.self) { site in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").font(.caption2).foregroundStyle(KindredTheme.mint)
                    Text(site).font(.subheadline).foregroundStyle(KindredTheme.subtext)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func startImport() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isImporting else { return }
        focused = false
        isImporting = true
        errorMessage = nil
        imported = nil
        Task {
            do {
                let recipe = try await service.importRecipe(from: trimmed)
                await MainActor.run {
                    imported = recipe
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't extract a recipe from that page. Try a different URL, or check that the page is publicly accessible."
                    isImporting = false
                }
            }
        }
    }
}

#Preview {
    URLImportView()
        .environment(SavedRecipeStore(seed: []))
        .preferredColorScheme(.dark)
}
