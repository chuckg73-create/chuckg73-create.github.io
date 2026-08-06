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

                equipmentSection(store: store)

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
                let on = store.profile.diets.contains(diet)
                Button {
                    if on { store.profile.diets.remove(diet) }
                    else { store.profile.diets.insert(diet) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? KindredTheme.accent : KindredTheme.faint)
                        Text(diet.title).foregroundStyle(KindredTheme.text)
                        Spacer()
                    }
                }
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .listRowBackground(KindredTheme.card)
    }

    private func equipmentSection(store storeRef: ProfileStore) -> some View {
        @Bindable var store = storeRef
        return Section {
            // Quick-add chips for common appliances not already selected.
            let unused = TasteProfile.commonEquipment.filter { item in
                !store.profile.equipment.contains { $0.caseInsensitiveCompare(item) == .orderedSame }
            }
            if !unused.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(unused, id: \.self) { item in
                        Button {
                            store.profile.equipment.append(item)
                        } label: {
                            Chip(text: item, systemImage: "plus", tint: KindredTheme.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            TokenEditor(tokens: $store.profile.equipment, placeholder: "e.g. Traeger", tint: KindredTheme.mint)
        } header: {
            Text("Kitchen equipment")
        } footer: {
            Text("Suggestions favor methods your gear enables — air-frying, smoking, sous vide, and so on.")
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
            Text("Your profile stays on your device. Your fridge photos and ingredient names go to Google Gemini to recognize food and build recipes — never your name or personal identifiers.")
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
