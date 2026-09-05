import SwiftUI

/// One-time welcome + quick taste setup shown on first launch.
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profileStore
    @State private var page = 0
    @State private var cuisineDraft = ""
    @State private var allergenDraft = ""

    var body: some View {
        ZStack {
            KindredBackground()
            TabView(selection: $page) {
                welcome.tag(0)
                quickTaste(store: profileStore).tag(1)
                howYouCook(store: profileStore).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(KindredTheme.brandGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: KindredTheme.accent.opacity(0.4), radius: 28, y: 12)
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 10) {
                Text("KindredTable").font(.largeTitle).fontWeight(.heavy)
                Text("Photograph your fridge. Cook what matches you.")
                    .font(.title3)
                    .foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 16) {
                feature("camera.viewfinder", "Snap & identify", "AI vision reads your ingredients — even labels and packaged goods.")
                feature("slider.horizontal.3", "Matched to you", "Meals tuned to your taste, diet, and time.")
                feature("bookmark.fill", "Save for later", "Keep the recipes you love in one place.")
            }
            .padding(.horizontal, 30)
            .padding(.top, 8)
            Spacer()
            Button { withAnimation { page = 1 } } label: {
                Text("Get started").fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(KindredTheme.brandGradient, in: Capsule())
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }

    private func quickTaste(store storeRef: ProfileStore) -> some View {
        @Bindable var store = storeRef
        return VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("A little about your taste")
                    .font(.title2).fontWeight(.bold)
                Text("This personalises your suggestions. You can change it any time.")
                    .font(.subheadline)
                    .foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(label: "Cuisines you love")
                        chipGrid(fullOptions(presets: Self.commonCuisines, selection: store.profile.lovedCuisines),
                                 selection: $store.profile.lovedCuisines, tint: KindredTheme.blue)
                        addCustomRow(draft: $cuisineDraft, selection: $store.profile.lovedCuisines,
                                     placeholder: "Add your own", tint: KindredTheme.blue)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(label: "Anything you don't like?")
                        Text("Ingredients to leave out of every suggestion — you can always add more later.")
                            .font(.caption2).foregroundStyle(KindredTheme.faint)
                        TokenEditor(tokens: $store.profile.dislikedIngredients, placeholder: "e.g. cilantro, chicken",
                                    tint: KindredTheme.subtext)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(label: "Any diets?")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                            ForEach(Diet.allCases) { diet in
                                let on = store.profile.diets.contains(diet)
                                Button {
                                    if on { store.profile.diets.remove(diet) } else { store.profile.diets.insert(diet) }
                                } label: {
                                    Chip(text: diet.title, tint: KindredTheme.accent, filled: on)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? [.isSelected] : [])
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(label: "How much heat?")
                        Picker("Spice", selection: $store.profile.spiceLevel) {
                            ForEach(SpiceLevel.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(label: "Any allergies?")
                        Text("These are strictly excluded from every suggestion.")
                            .font(.caption2).foregroundStyle(KindredTheme.faint)
                        chipGrid(fullOptions(presets: Self.commonAllergens, selection: store.profile.allergens),
                                 selection: $store.profile.allergens, tint: KindredTheme.coral)
                        addCustomRow(draft: $allergenDraft, selection: $store.profile.allergens,
                                     placeholder: "Add your own", tint: KindredTheme.coral)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 12)
            }

            Button {
                withAnimation { page = 2 }
            } label: {
                Text("Next").fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(KindredTheme.brandGradient, in: Capsule())
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }

    private func howYouCook(store storeRef: ProfileStore) -> some View {
        @Bindable var store = storeRef
        return VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("How you cook")
                    .font(.title2).fontWeight(.bold)
                Text("Recipes are matched to your available time and experience — change any of this later.")
                    .font(.subheadline)
                    .foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionHeader(label: "Max cook time")
                        Spacer()
                        Text("\(store.profile.maxCookMinutes) min")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KindredTheme.accent)
                    }
                    Slider(value: Binding(
                        get: { Double(store.profile.maxCookMinutes) },
                        set: { store.profile.maxCookMinutes = Int($0) }
                    ), in: 15...120, step: 15)
                    .tint(KindredTheme.accent)
                    HStack {
                        Text("15 min").font(.caption2).foregroundStyle(KindredTheme.faint)
                        Spacer()
                        Text("2 hrs").font(.caption2).foregroundStyle(KindredTheme.faint)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(label: "Your skill level")
                    VStack(spacing: 8) {
                        ForEach(CookingSkill.allCases) { skill in
                            let selected = store.profile.skill == skill
                            Button { store.profile.skill = skill } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: skillIcon(skill))
                                        .font(.title3)
                                        .foregroundStyle(selected ? .white : KindredTheme.accent)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            selected ? AnyShapeStyle(KindredTheme.brandGradient)
                                                     : AnyShapeStyle(KindredTheme.accent.opacity(0.12)),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(skill.title).font(.subheadline.weight(.semibold))
                                            .foregroundStyle(KindredTheme.text)
                                        Text(skillSubtitle(skill)).font(.caption)
                                            .foregroundStyle(KindredTheme.subtext)
                                    }
                                    Spacer()
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(KindredTheme.accent)
                                    }
                                }
                                .padding(12)
                                .background(
                                    selected ? KindredTheme.accent.opacity(0.10) : KindredTheme.card,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(selected ? KindredTheme.accent.opacity(0.5) : KindredTheme.hairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            Button {
                store.hasOnboarded = true
            } label: {
                Text("Start cooking").fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(KindredTheme.brandGradient, in: Capsule())
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }

    private func skillIcon(_ skill: CookingSkill) -> String {
        switch skill {
        case .beginner:    return "hands.sparkles"
        case .comfortable: return "frying.pan"
        case .confident:   return "flame.fill"
        }
    }

    private func skillSubtitle(_ skill: CookingSkill) -> String {
        switch skill {
        case .beginner:    return "Simple steps, minimal prep"
        case .comfortable: return "Happy with most everyday meals"
        case .confident:   return "Bring on the complex stuff"
        }
    }

    static let commonCuisines = ["Italian", "Mexican", "Thai", "Indian", "Chinese", "Japanese",
                                 "Mediterranean", "American", "French", "Korean", "Middle Eastern", "Greek"]
    static let commonAllergens = ["Peanuts", "Tree nuts", "Shellfish", "Dairy", "Gluten", "Eggs", "Soy", "Fish"]

    /// Tappable chips that toggle a string into/out of a `[String]` profile field
    /// (case-insensitive, preserving anything the cook already typed).
    private func chipGrid(_ options: [String], selection: Binding<[String]>, tint: Color) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { item in
                let on = selection.wrappedValue.contains { $0.caseInsensitiveCompare(item) == .orderedSame }
                Button {
                    if on {
                        selection.wrappedValue.removeAll { $0.caseInsensitiveCompare(item) == .orderedSame }
                    } else {
                        selection.wrappedValue.append(item)
                    }
                } label: {
                    Chip(text: item, tint: tint, filled: on)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }

    /// Presets plus anything the cook already typed in that isn't one of them —
    /// so a custom entry ("chicken") shows up as a real, removable chip in the
    /// same grid instead of only living in the underlying array.
    private func fullOptions(presets: [String], selection: [String]) -> [String] {
        let custom = selection.filter { value in
            !presets.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
        }
        return presets + custom
    }

    /// A free-text fallback for when what the cook wants isn't in the preset
    /// chips above — types anything and it joins the grid as a selected chip.
    private func addCustomRow(draft: Binding<String>, selection: Binding<[String]>,
                               placeholder: String, tint: Color) -> some View {
        HStack {
            TextField(placeholder, text: draft)
                .textInputAutocapitalization(.words)
                .onSubmit { addCustom(draft: draft, selection: selection) }
            Button("Add") { addCustom(draft: draft, selection: selection) }
                .font(.caption.weight(.semibold)).foregroundStyle(tint)
                .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addCustom(draft: Binding<String>, selection: Binding<[String]>) {
        let value = draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !selection.wrappedValue.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
            draft.wrappedValue = ""
            return
        }
        selection.wrappedValue.append(value)
        draft.wrappedValue = ""
    }

    private func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3).foregroundStyle(KindredTheme.accent)
                .frame(width: 40, height: 40)
                .background(KindredTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(body).font(.caption).foregroundStyle(KindredTheme.subtext)
            }
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(ProfileStore(seed: nil))
        .preferredColorScheme(.dark)
}
