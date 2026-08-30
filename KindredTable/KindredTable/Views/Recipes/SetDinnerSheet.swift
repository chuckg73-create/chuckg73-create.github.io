import SwiftUI

/// Pick a specific dinner for a day — for recurring theme nights (Tuesday
/// smashed burgers, Thursday pizza). Generates the recipe, sets it as that
/// night's dinner, and saves it to the cookbook.
struct SetDinnerSheet: View {
    let day: Date
    var onChange: () -> Void

    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()
    @State private var dish = ""
    @State private var isWorking = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    private static let ideas = ["Smashed burgers", "Pizza night", "Taco night",
                                "Pasta", "Stir-fry", "Sheet-pan chicken", "Breakfast for dinner"]

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("What's for dinner \(MealPlanView.dayLabel(day).lowercased())?")
                            .font(.title2).fontWeight(.bold).foregroundStyle(KindredTheme.text)
                        Text("Name a dish and we'll build the recipe, tuned to your taste, and add it to your cookbook.")
                            .font(.subheadline).foregroundStyle(KindredTheme.subtext)

                        HStack(spacing: 10) {
                            Image(systemName: "fork.knife").foregroundStyle(KindredTheme.accent)
                            TextField("e.g. smashed burgers", text: $dish)
                                .focused($focused)
                                .submitLabel(.go)
                                .onSubmit { generate() }
                        }
                        .padding(14)
                        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))

                        ThemeIdeaChips(items: Self.ideas) { idea in
                            dish = idea
                            generate()
                        }

                        Button(action: generate) {
                            HStack(spacing: 8) {
                                if isWorking { ProgressView().controlSize(.small).tint(.white); Text("Building your recipe…") }
                                else { Image(systemName: "sparkles"); Text("Set this dinner") }
                            }
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(KindredTheme.brandGradient, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking || dish.trimmingCharacters(in: .whitespaces).isEmpty)

                        if let errorText {
                            Text(errorText).font(.caption).foregroundStyle(KindredTheme.amber)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Set dinner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { focused = true }
        }
    }

    private func generate() {
        let wanted = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty, !isWorking else { return }
        focused = false
        isWorking = true
        errorText = nil
        Task {
            do {
                let recipes = try await service.craveRecipes(
                    dish: wanted,
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile),
                    count: 1,
                    servings: household.servings
                )
                guard let recipe = recipes.first else {
                    await MainActor.run { isWorking = false; errorText = "Couldn't build that one — try another dish." }
                    return
                }
                await MainActor.run {
                    mealPlan.setDinner(recipe, on: day)   // replaces whatever was there
                    saved.add(recipe)                     // keep it in the cookbook
                    onChange()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorText = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}

/// A simple wrapping row of tappable suggestion chips.
private struct ThemeIdeaChips: View {
    let items: [String]
    var onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(KindredTheme.text)
                        .background(KindredTheme.accent.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
