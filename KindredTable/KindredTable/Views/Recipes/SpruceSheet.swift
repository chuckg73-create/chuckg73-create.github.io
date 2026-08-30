import SwiftUI

/// "Spruce it up" — chef's touches to make a dish feel special, tuned to the
/// cook's taste. They can save the ones they like to the recipe's notes.
struct SpruceSheet: View {
    let recipe: Recipe

    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(RecipeNotesStore.self) private var notesStore
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()

    enum Phase { case loading, ready([SpruceIdea]), failed(String) }
    @State private var phase: Phase = .loading
    @State private var added = false

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                switch phase {
                case .loading:          loadingView
                case .failed(let m):    failedView(m)
                case .ready(let ideas): readyView(ideas)
                }
            }
            .navigationTitle("Spruce it up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .task { await load() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text("Finding ways to elevate\n\(recipe.title)…")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func failedView(_ message: String) -> some View {
        EmptyState(systemImage: "sparkles",
                   title: "Couldn't find touches",
                   message: message,
                   actionTitle: "Try again",
                   action: { Task { await load() } })
    }

    private func readyView(_ ideas: [SpruceIdea]) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Chef's touches for \(recipe.title)")
                        .font(.headline).foregroundStyle(KindredTheme.text)
                    Text("Little upgrades that make it feel special — pick what sounds good.")
                        .font(.caption).foregroundStyle(KindredTheme.subtext)

                    ForEach(ideas) { idea in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: idea.systemImage)
                                .font(.title3).foregroundStyle(KindredTheme.accent)
                                .frame(width: 34, height: 34)
                                .background(KindredTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(idea.kind.uppercased())
                                    .font(.caption2.weight(.semibold)).foregroundStyle(KindredTheme.faint)
                                    .tracking(0.5)
                                Text(idea.text)
                                    .font(.subheadline).foregroundStyle(KindredTheme.text)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
            saveBar(ideas)
        }
    }

    private func saveBar(_ ideas: [SpruceIdea]) -> some View {
        VStack(spacing: 8) {
            Button {
                addToNotes(ideas)
                withAnimation { added = true }
            } label: {
                Label(added ? "Saved to notes" : "Save these to my notes",
                      systemImage: added ? "checkmark.circle.fill" : "note.text.badge.plus")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(added ? AnyShapeStyle(KindredTheme.mint) : AnyShapeStyle(KindredTheme.brandGradient),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(added)
            Button("Suggest more") { Task { await load() } }
                .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.accent)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func load() async {
        phase = .loading
        added = false
        do {
            let ideas = try await service.spruceUp(
                recipe,
                profile: household.effectiveProfile(you: profileStore.profile)
            )
            phase = .ready(ideas)
        } catch {
            phase = .failed((error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func addToNotes(_ ideas: [SpruceIdea]) {
        let existing = notesStore.note(for: recipe).trimmingCharacters(in: .whitespacesAndNewlines)
        let block = "Chef's touches:\n" + ideas.map { "• \($0.text)" }.joined(separator: "\n")
        let combined = existing.isEmpty ? block : existing + "\n\n" + block
        notesStore.setNote(combined, for: recipe)
    }
}
