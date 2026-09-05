import SwiftUI

/// Edits the user's taste profile — their cooking "DNA" used to personalise
/// suggestions. Bound directly to the persisted `ProfileStore`.
struct TasteProfileView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(TasteFeedbackStore.self) private var feedback
    @Environment(TastePreferenceStore.self) private var preferences
    @Environment(StaplesStore.self) private var staples
    @Environment(\.dismiss) private var dismiss
    @State private var showEquipmentScan = false
    @State private var stapleDraft = ""
    @State private var showFullResetConfirm = false

    var body: some View {
        @Bindable var store = profileStore

        ZStack {
            KindredBackground()
            Form {
                if !feedback.isEmpty || !preferences.isEmpty { learnedSection }
                dietSection(store: store)
                eatingStyleSection(store: store)

                Section("Cuisines you love") {
                    TokenEditor(tokens: $store.profile.lovedCuisines, placeholder: "e.g. Thai", tint: KindredTheme.blue)
                }
                .listRowBackground(KindredTheme.card)

                Section("Ingredients to avoid") {
                    TokenEditor(tokens: $store.profile.dislikedIngredients, placeholder: "e.g. cilantro", tint: KindredTheme.subtext)
                }
                .listRowBackground(KindredTheme.card)

                staplesSection

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
                fullResetSection
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
        .sheet(isPresented: $showEquipmentScan) { EquipmentScanView() }
        .alert("Reset your taste profile?", isPresented: $showFullResetConfirm) {
            Button("Reset Everything", role: .destructive) { profileStore.profile = .empty }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears diets, cuisines, dislikes, allergens, equipment and notes back to blank. Your saved recipes, pantry and grocery list aren't touched.")
        }
    }

    /// A true full reset — every field on this screen back to blank — distinct
    /// from `learnedSection`'s reset, which only clears the more/less-like-this
    /// learned tuning and leaves what the cook typed in here alone.
    private var fullResetSection: some View {
        Section {
            Button(role: .destructive) {
                showFullResetConfirm = true
            } label: {
                Label("Reset my taste profile", systemImage: "arrow.counterclockwise.circle")
            }
        } footer: {
            Text("Starts your whole taste profile over from blank.")
        }
        .listRowBackground(KindredTheme.card)
    }

    /// Makes the personalization tangible: what the engine has learned from the
    /// cook's ratings and their more/less-like-this taps.
    private var learnedSection: some View {
        Section {
            if feedback.lovedCount > 0 {
                learnedRow(icon: "heart.fill", tint: KindredTheme.coral,
                           title: "You’ve loved \(feedback.lovedCount) \(feedback.lovedCount == 1 ? "dish" : "dishes")",
                           detail: feedback.lovedTags.prefix(6).joined(separator: ", "))
            }
            if !preferences.boosted.isEmpty {
                learnedRow(icon: "hand.thumbsup.fill", tint: KindredTheme.accent,
                           title: "More of",
                           detail: preferences.boosted.prefix(6).joined(separator: ", "))
            }
            if !preferences.suppressed.isEmpty {
                learnedRow(icon: "hand.thumbsdown.fill", tint: KindredTheme.faint,
                           title: "Less of",
                           detail: preferences.suppressed.prefix(6).joined(separator: ", "))
            }
            if !preferences.isEmpty {
                Button(role: .destructive) {
                    preferences.clear()
                } label: {
                    Label("Reset my more/less tuning", systemImage: "arrow.counterclockwise")
                }
            }
        } header: {
            Text("What we’ve learned")
        } footer: {
            Text("Built from dishes you’ve rated and your “more/less like this” taps. It sharpens every suggestion.")
        }
        .listRowBackground(KindredTheme.card)
    }

    private func learnedRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(KindredTheme.text)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(KindredTheme.subtext)
                }
            }
            Spacer()
        }
    }

    /// Staples the cook always has — excluded from every shopping list.
    private var staplesSection: some View {
        Section {
            if !staples.names.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                          alignment: .leading, spacing: 8) {
                    ForEach(staples.names, id: \.self) { name in
                        Button { staples.remove(name) } label: {
                            HStack(spacing: 4) {
                                Text(name).font(.caption).fontWeight(.medium)
                                Image(systemName: "xmark").font(.system(size: 8))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .foregroundStyle(KindredTheme.mint)
                            .background(KindredTheme.mint.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            HStack {
                TextField("e.g. soy sauce", text: $stapleDraft)
                    .textInputAutocapitalization(.never)
                    .onSubmit(addStaple)
                Button("Add", action: addStaple)
                    .font(.subheadline)
                    .disabled(stapleDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Pantry staples")
        } footer: {
            Text("Things you always keep on hand. They’re treated as available and never added to your shopping list.")
        }
        .listRowBackground(KindredTheme.card)
    }

    private func addStaple() {
        staples.add(stapleDraft)
        stapleDraft = ""
    }

    private func eatingStyleSection(store storeRef: ProfileStore) -> some View {
        @Bindable var store = storeRef
        return Section {
            ForEach(EatingStyle.allCases) { style in
                let on = store.profile.eatingStyles.contains(style)
                Button {
                    if on { store.profile.eatingStyles.remove(style) }
                    else { store.profile.eatingStyles.insert(style) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? KindredTheme.accent : KindredTheme.faint)
                        Image(systemName: style.systemImage)
                            .font(.caption).foregroundStyle(on ? KindredTheme.accent : KindredTheme.subtext)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(style.title).foregroundStyle(KindredTheme.text)
                            Text(style.subtitle).font(.caption).foregroundStyle(KindredTheme.subtext)
                        }
                        Spacer()
                    }
                }
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        } header: {
            Text("Eating style")
        } footer: {
            Text("Shapes every suggestion toward how you like to eat. Health-oriented styles are general guidance, not medical advice — check with your doctor or dietitian for your own targets.")
        }
        .listRowBackground(KindredTheme.card)
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
            Button {
                showEquipmentScan = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .foregroundStyle(KindredTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Scan my kitchen").foregroundStyle(KindredTheme.text)
                            .font(.subheadline.weight(.semibold))
                        Text("Snap a photo — we'll spot your appliances")
                            .font(.caption).foregroundStyle(KindredTheme.subtext)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(KindredTheme.faint)
                }
            }
            // Quick-add chips for common appliances not already selected.
            let unused = TasteProfile.commonEquipment.filter { item in
                !EquipmentMatcher.contains(store.profile.equipment, item)
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
        .environment(TasteFeedbackStore())
        .environment(TastePreferenceStore())
        .environment(StaplesStore())
        .preferredColorScheme(.dark)
}
