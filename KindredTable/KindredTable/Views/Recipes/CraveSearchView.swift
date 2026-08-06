import SwiftUI

/// "Cook a craving" — type any dish (e.g. "london broil") and Gemini builds a
/// full recipe tuned to your taste, marking what you'd need to buy as a shopping
/// list. The result opens in the normal recipe detail (with Add-to-grocery).
struct CraveSearchView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(HouseholdStore.self) private var household
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var phase: Phase = .idle
    private let service = GeminiRecipeService()

    enum Phase: Equatable {
        case idle, loading
        case results([Recipe])
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                VStack(spacing: 16) {
                    searchField
                    content
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Cook a craving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var searchField: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "fork.knife").foregroundStyle(KindredTheme.accent)
                TextField("What do you feel like? e.g. london broil", text: $query)
                    .foregroundStyle(KindredTheme.text)
                    .submitLabel(.search)
                    .onSubmit(run)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12))

            Button(action: run) {
                Label("Find recipe & shopping list", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(KindredTheme.accent)
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || phase == .loading)
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .idle:
            VStack(spacing: 10) {
                Text("Crave anything.")
                    .font(.headline).foregroundStyle(KindredTheme.text)
                Text("Type a dish and Kindred Kitchen builds a full recipe tuned to your taste — with a shopping list for whatever you don't have on hand.")
                    .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

        case .loading:
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(KindredTheme.accent)
                Text("Cooking up \(query)…").foregroundStyle(KindredTheme.subtext)
            }
            .padding(.top, 32)

        case .results(let recipes):
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(recipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeCard(recipe: recipe, isSaved: saved.isSaved(recipe), onSave: { saved.toggle(recipe) })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }

        case .failed(let message):
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").font(.title).foregroundStyle(KindredTheme.amber)
                Text(message).font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
        }
    }

    private func run() {
        let dish = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dish.isEmpty else { return }
        phase = .loading
        Task {
            do {
                let recipes = try await service.craveRecipes(
                    dish: dish,
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile)
                )
                phase = .results(recipes)
            } catch {
                let message = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                phase = .failed(message)
            }
        }
    }
}
