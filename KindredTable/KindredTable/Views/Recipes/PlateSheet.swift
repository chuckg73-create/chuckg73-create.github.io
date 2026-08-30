import SwiftUI

/// "Complete the plate" — pick a main and let KindredTable choose sides that
/// pair with it, each a full recipe you can open and save.
struct PlateSheet: View {
    let main: Recipe

    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()

    enum Phase { case loading, ready([Recipe]), failed(String) }
    @State private var phase: Phase = .loading
    @State private var savedSides = false

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                switch phase {
                case .loading:      loadingView
                case .failed(let m): failedView(m)
                case .ready(let sides): readyView(sides)
                }
            }
            .navigationTitle("Complete the plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .task { await load() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text("Picking sides that pair with\n\(main.title)…")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            EmptyState(systemImage: "exclamationmark.triangle",
                       title: "Couldn't build the plate",
                       message: message,
                       actionTitle: "Try again",
                       action: { Task { await load() } })
        }
    }

    private func readyView(_ sides: [Recipe]) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sides for \(main.title)")
                        .font(.headline).foregroundStyle(KindredTheme.text)
                    Text("Tap a side to see its recipe. Save the ones you like to your cookbook.")
                        .font(.caption).foregroundStyle(KindredTheme.subtext)

                    ForEach(sides) { side in
                        NavigationLink {
                            RecipeDetailView(recipe: side)
                        } label: {
                            RecipeCard(recipe: side,
                                       isSaved: saved.isSaved(side),
                                       onSave: { saved.toggle(side) })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
            saveBar(sides)
        }
    }

    private func saveBar(_ sides: [Recipe]) -> some View {
        VStack(spacing: 8) {
            Button {
                for side in sides where !saved.isSaved(side) { saved.add(side) }
                withAnimation { savedSides = true }
            } label: {
                Label(savedSides ? "Saved to cookbook" : "Save these sides to cookbook",
                      systemImage: savedSides ? "checkmark.circle.fill" : "books.vertical.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(savedSides ? AnyShapeStyle(KindredTheme.mint) : AnyShapeStyle(KindredTheme.brandGradient),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(savedSides)
            Button("Suggest different sides") { Task { await load() } }
                .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.accent)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func load() async {
        phase = .loading
        savedSides = false
        do {
            let sides = try await service.suggestSides(
                for: main,
                from: pantry.ingredients,
                profile: household.effectiveProfile(you: profileStore.profile),
                count: 2,
                servings: max(1, main.servings)
            )
            phase = .ready(sides)
        } catch {
            phase = .failed((error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
