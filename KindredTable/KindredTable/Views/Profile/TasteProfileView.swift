import SwiftUI

/// Edits the user's taste profile — their cooking "DNA" used to personalise
/// suggestions. Bound directly to the persisted `ProfileStore`.
struct TasteProfileView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = profileStore

        ZStack {
            KindredBackground()
            Form {
                dietSection(store: store)

                Section("Cuisines you love") {
                    TokenEditor(tokens: $store.profile.lovedCuisines, placeholder: "e.g. Thai", tint: KindredTheme.blue)
                }
                .listRowBackground(KindredTheme.card)

                Section("Ingredients to avoid") {
                    TokenEditor(tokens: $store.profile.dislikedIngredients, placeholder: "e.g. cilantro", tint: KindredTheme.subtext)
                }
                .listRowBackground(KindredTheme.card)

                Section {
                    TokenEditor(tokens: $store.profile.allergens, placeholder: "e.g. peanuts", tint: KindredTheme.coral)
                } header: {
                    Text("Allergens")
                } footer: {
                    Text("Allergens are strictly excluded from every suggestion.")
                }
                .listRowBackground(KindredTheme.card)

                Section("Preferences") {
                    Picker("Spice", selection: $store.profile.spiceLevel) {
                        ForEach(SpiceLevel.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Cooking skill", selection: $store.profile.skill) {
                        ForEach(CookingSkill.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(value: $store.profile.maxCookMinutes, in: 10...180, step: 5) {
                        Text("Max cook time: \(store.profile.maxCookMinutes) min")
                    }
                }
                .listRowBackground(KindredTheme.card)

                Section("Notes") {
                    TextField("Anything else? e.g. cooking for a toddler", text: $store.profile.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(KindredTheme.card)

                apiStatusSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Your taste")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }
        }
    }

    private func dietSection(store: ProfileStore) -> some View {
        Section("Diet") {
            ForEach(Diet.allCases) { diet in
                Button {
                    if store.profile.diets.contains(diet) {
                        store.profile.diets.remove(diet)
                    } else {
                        store.profile.diets.insert(diet)
                    }
                } label: {
                    HStack {
                        Text(diet.title).foregroundStyle(KindredTheme.text)
                        Spacer()
                        if store.profile.diets.contains(diet) {
                            Image(systemName: "checkmark").foregroundStyle(KindredTheme.accent)
                        }
                    }
                }
            }
        }
        .listRowBackground(KindredTheme.card)
    }

    private var apiStatusSection: some View {
        Section {
            HStack {
                Image(systemName: AppConfig.hasGeminiKey ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(AppConfig.hasGeminiKey ? KindredTheme.mint : KindredTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppConfig.hasGeminiKey ? "Gemini connected" : "No Gemini key")
                        .font(.subheadline).fontWeight(.medium)
                    Text(AppConfig.hasGeminiKey
                         ? "Suggestions are tailored to your exact pantry."
                         : "Running in sample mode. See the README to add a key.")
                        .font(.caption).foregroundStyle(KindredTheme.faint)
                }
            }
        } footer: {
            Text("Your profile stays on your device. Only ingredient names and preferences — never personal identifiers — are sent to generate recipes.")
        }
        .listRowBackground(KindredTheme.card)
    }
}

/// A lightweight tag-style editor for a list of short strings.
struct TokenEditor: View {
    @Binding var tokens: [String]
    var placeholder: String
    var tint: Color

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tokens.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(tokens, id: \.self) { token in
                        Button {
                            tokens.removeAll { $0 == token }
                        } label: {
                            HStack(spacing: 4) {
                                Text(token).font(.caption).fontWeight(.medium)
                                Image(systemName: "xmark").font(.system(size: 8))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .foregroundStyle(tint)
                            .background(tint.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .onSubmit(add)
                Button("Add", action: add)
                    .font(.subheadline)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func add() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !tokens.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
            draft = ""
            return
        }
        tokens.append(value)
        draft = ""
    }
}

#Preview {
    NavigationStack { TasteProfileView() }
        .environment(ProfileStore(seed: .starter))
        .preferredColorScheme(.dark)
}
