import SwiftUI

/// The conversational chef: tell it what you want in plain words ("plan me an
/// easy week, no chicken"), and it routes your request over the app's existing
/// engines — never inventing recipes, just orchestrating what's built.
struct ChefView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(RecentSuggestionsStore.self) private var recent
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()

    @State private var input = ""
    @State private var isThinking = false
    @State private var reply: String?
    @State private var results: [Recipe] = []
    @State private var lastAction: ChefIntent.Action?
    @State private var errorText: String?
    @State private var addedToWeek = false
    @FocusState private var focused: Bool

    private static let suggestions = ["Plan me an easy week",
                                      "Something quick, no dairy",
                                      "Make me chicken tacos",
                                      "3 dinners for 2, no chicken"]

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                VStack(spacing: 0) {
                    ScrollView { resultsArea.padding(20) }
                    inputBar
                }
            }
            .navigationTitle("Ask the kitchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onAppear { focused = true }
        }
    }

    @ViewBuilder private var resultsArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            if reply == nil, results.isEmpty, !isThinking { introCard }

            if let reply {
                Label(reply, systemImage: "sparkles")
                    .font(.callout.weight(.medium)).foregroundStyle(KindredTheme.text)
            }
            if isThinking {
                HStack(spacing: 10) {
                    ProgressView().tint(KindredTheme.accent)
                    Text("Thinking…").foregroundStyle(KindredTheme.subtext)
                }
            }
            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(KindredTheme.amber)
            }
            if lastAction == .planWeek, !results.isEmpty { addToWeekButton }

            ForEach(results) { recipe in
                NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                    RecipeCard(recipe: recipe, isSaved: saved.isSaved(recipe), onSave: { saved.toggle(recipe) })
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tell me what you're in the mood for")
                .font(.title3).fontWeight(.bold).foregroundStyle(KindredTheme.text)
            Text("I'll work from your taste and what's in your kitchen. Try:")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
                      alignment: .leading, spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button { input = suggestion; submit() } label: {
                        Text(suggestion)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .foregroundStyle(KindredTheme.text)
                            .background(KindredTheme.accent.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addToWeekButton: some View {
        Button {
            for (day, recipe) in zip(mealPlan.upcomingDays(), results) {
                mealPlan.setDinner(recipe, on: day)
            }
            withAnimation { addedToWeek = true }
        } label: {
            Label(addedToWeek ? "Added to your week" : "Add these to my week",
                  systemImage: addedToWeek ? "checkmark.circle.fill" : "calendar.badge.plus")
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(addedToWeek ? AnyShapeStyle(KindredTheme.mint) : AnyShapeStyle(KindredTheme.brandGradient), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(addedToWeek)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask me to cook or plan…", text: $input)
                .focused($focused).submitLabel(.send).onSubmit(submit)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(KindredTheme.card, in: Capsule())
                .overlay(Capsule().stroke(KindredTheme.hairline, lineWidth: 1))
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? KindredTheme.accent : KindredTheme.faint)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !isThinking
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        focused = false
        isThinking = true
        errorText = nil
        addedToWeek = false
        reply = nil
        results = []
        Task {
            do {
                let (intent, recipes) = try await service.chef(
                    text,
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile),
                    defaultServings: household.servings
                )
                await MainActor.run {
                    isThinking = false
                    lastAction = intent.action
                    results = recipes
                    recent.record(recipes)
                    // Guide the cook when we couldn't produce recipes.
                    if recipes.isEmpty, intent.action == .planWeek || intent.action == .findMeals, pantry.isEmpty {
                        reply = "Snap your fridge or pantry first and I'll plan from what you've got — or name a specific dish and I'll build it."
                    } else if recipes.isEmpty, intent.action == .unknown {
                        reply = intent.reply.isEmpty
                            ? "I'm your kitchen helper — try \u{201C}plan me an easy week\u{201D} or \u{201C}something quick with chicken.\u{201D}"
                            : intent.reply
                    } else {
                        reply = intent.reply.isEmpty ? nil : intent.reply
                    }
                    input = ""
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    errorText = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}
