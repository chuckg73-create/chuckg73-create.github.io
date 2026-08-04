import SwiftUI

/// One-time welcome + quick taste setup shown on first launch.
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profileStore
    @State private var page = 0

    var body: some View {
        ZStack {
            KindredBackground()
            TabView(selection: $page) {
                welcome.tag(0)
                quickTaste(store: profileStore).tag(1)
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
                feature("camera.viewfinder", "Snap & identify", "Ingredients recognised privately, on your device.")
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
                }
                .padding(.horizontal, 30)
            }

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
