import SwiftUI
import PhotosUI
import UIKit

/// Photograph a dish you love — at a restaurant, a friend's table, anywhere —
/// and get a recipe to recreate it at home, tailored to your taste profile.
struct RecreateDishView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(SavedRecipeStore.self) private var cookbook
    @Environment(\.dismiss) private var dismiss

    var onCook: ((Recipe) -> Void)?

    private let service = GeminiRecipeService()

    enum Phase: Equatable {
        case choose
        case recognizing
        case review(Recipe)
        case failed(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.choose, .choose), (.recognizing, .recognizing): return true
            case (.failed(let a), .failed(let b)): return a == b
            case (.review(let a), .review(let b)): return a.id == b.id
            default: return false
            }
        }
    }

    @State private var phase: Phase = .choose
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var saved = false
    @State private var showAllIngredients = false
    @State private var dishHint = ""
    @FocusState private var hintFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .choose:           chooseState
                        case .recognizing:      recognizingState
                        case .review(let r):    reviewState(r)
                        case .failed(let msg):  failedState(msg)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Recreate a dish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in process(image) }
                    .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await loadPickedPhoto(item) }
            }
        }
    }

    // MARK: Phases

    private var chooseState: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 52))
                    .foregroundStyle(KindredTheme.coral)
                Text("See a dish you love?")
                    .font(.title2).fontWeight(.bold).foregroundStyle(KindredTheme.text)
                Text("Photograph it and get a recipe to make it at home — tuned to your taste.")
                    .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)

            hintField

            VStack(spacing: 12) {
                Button {
                    hintFocused = false
                    showCamera = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Take a photo").fontWeight(.semibold)
                            Text("Point your camera at the dish").font(.caption).opacity(0.85)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle").font(.title3).foregroundStyle(KindredTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Choose from library").fontWeight(.semibold).foregroundStyle(KindredTheme.text)
                            Text("Pick a photo you already have").font(.caption).foregroundStyle(KindredTheme.subtext)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(KindredTheme.faint)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 16)
                    .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(KindredTheme.hairline, lineWidth: 1))
                }

                examplePrompts
            }
        }
    }

    private var hintField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Know the dish or restaurant? (optional)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(KindredTheme.faint)
            HStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass")
                    .font(.subheadline).foregroundStyle(KindredTheme.accent)
                TextField("e.g. duck confit at Bouchon", text: $dishHint)
                    .focused($hintFocused)
                    .submitLabel(.done)
                    .onSubmit { hintFocused = false }
                if !dishHint.isEmpty {
                    Button { dishHint = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(KindredTheme.faint)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                hintFocused ? KindredTheme.accent.opacity(0.5) : KindredTheme.hairline, lineWidth: 1))
            Text("Helps when the dish name or restaurant is well-known — Gemini will use it to nail the authentic recipe.")
                .font(.caption2).foregroundStyle(KindredTheme.faint)
        }
    }

    private var examplePrompts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Works great for")
                .font(.caption.weight(.semibold))
                .foregroundStyle(KindredTheme.faint)
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Restaurant entrees", "Dishes at a friend's", "Menu photos", "Food magazines", "Food at events"], id: \.self) { label in
                        Text(label)
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(KindredTheme.accent)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(KindredTheme.accent.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var recognizingState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            ProgressView().controlSize(.large).tint(KindredTheme.coral)
            VStack(spacing: 6) {
                Text("Studying that dish…")
                    .font(.headline).foregroundStyle(KindredTheme.text)
                Text("Identifying what it is and writing you a recipe.")
                    .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func reviewState(_ recipe: Recipe) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Got it!")
                    .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.coral)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(KindredTheme.coral.opacity(0.12), in: Capsule())
                Text(recipe.title)
                    .font(.title2).fontWeight(.bold).foregroundStyle(KindredTheme.text)
                    .multilineTextAlignment(.center)
                Text(recipe.summary)
                    .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            HStack(spacing: 20) {
                statBadge("\(recipe.totalMinutes) min", "clock")
                statBadge("\(recipe.servings) serving\(recipe.servings == 1 ? "" : "s")", "person.2")
                statBadge(recipe.difficulty.title, "chart.bar")
            }

            ingredientCard(recipe)

            if !recipe.whyYoullLikeIt.isEmpty {
                Text(recipe.whyYoullLikeIt)
                    .font(.subheadline).italic()
                    .foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            ctaStack(recipe)
        }
    }

    private func statBadge(_ label: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(KindredTheme.accent)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))
    }

    private func ingredientCard(_ recipe: Recipe) -> some View {
        let shown = showAllIngredients ? recipe.ingredients : Array(recipe.ingredients.prefix(6))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.text)
                Spacer()
                Text("\(recipe.ingredients.count) items")
                    .font(.caption).foregroundStyle(KindredTheme.faint)
            }
            ForEach(shown) { ing in
                HStack(spacing: 10) {
                    Circle().fill(KindredTheme.accent.opacity(0.3)).frame(width: 6, height: 6)
                    Text(ing.amount.isEmpty ? ing.name : "\(ing.amount) \(ing.name)")
                        .font(.subheadline).foregroundStyle(KindredTheme.text)
                        .lineLimit(1)
                    Spacer()
                }
            }
            if recipe.ingredients.count > 6 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAllIngredients.toggle() }
                } label: {
                    Text(showAllIngredients
                         ? "Show less"
                         : "+ \(recipe.ingredients.count - 6) more ingredients")
                        .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous).stroke(KindredTheme.hairline, lineWidth: 1))
    }

    private func ctaStack(_ recipe: Recipe) -> some View {
        VStack(spacing: 10) {
            if let cookAction = onCook {
                Button {
                    cookbook.add(recipe)
                    cookAction(recipe)
                    dismiss()
                } label: {
                    Label("Cook it now", systemImage: "flame.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation { saved = true }
                cookbook.add(recipe)
                if onCook == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                }
            } label: {
                Label(saved ? "Saved to cookbook" : "Save to cookbook",
                      systemImage: saved ? "checkmark.circle.fill" : "books.vertical.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(saved ? KindredTheme.mint : KindredTheme.accent)
                    .background(
                        saved
                            ? KindredTheme.mint.opacity(0.12)
                            : KindredTheme.accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                        saved ? KindredTheme.mint.opacity(0.3) : KindredTheme.accent.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(saved)

            Button("Try a different photo") { phase = .choose; saved = false; showAllIngredients = false; dishHint = "" }
                .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.faint)
        }
        .padding(.top, 4)
    }

    private func failedState(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            Image(systemName: "camera.badge.exclamationmark")
                .font(.system(size: 48)).foregroundStyle(KindredTheme.faint)
            VStack(spacing: 8) {
                Text("Couldn't identify a dish")
                    .font(.headline).foregroundStyle(KindredTheme.text)
                Text(message)
                    .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            Button("Try again") { phase = .choose; showAllIngredients = false; dishHint = "" }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .buttonStyle(.plain)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        photoItem = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            await MainActor.run { phase = .failed("That photo couldn't be opened. Try another.") }
            return
        }
        await MainActor.run { process(image) }
    }

    private func process(_ image: UIImage) {
        guard let jpeg = image.jpegForUpload() else {
            phase = .failed("Couldn't prepare the photo. Try another one.")
            return
        }
        phase = .recognizing
        hintFocused = false
        let profile = household.effectiveProfile(you: profileStore.profile)
        let hint = dishHint.trimmingCharacters(in: .whitespacesAndNewlines)
        let svc = service
        Task {
            do {
                let recipe = try await svc.recreateFromPhoto(jpegData: jpeg, profile: profile, hint: hint.isEmpty ? nil : hint)
                await MainActor.run { phase = .review(recipe) }
            } catch {
                let msg = (error as? RecipeServiceError)?.errorDescription
                    ?? "That photo didn't return a dish. Try a clearer shot or a different angle."
                await MainActor.run { phase = .failed(msg) }
            }
        }
    }
}

#Preview {
    RecreateDishView()
        .environment(ProfileStore(seed: .starter))
        .environment(HouseholdStore())
        .environment(SavedRecipeStore())
        .preferredColorScheme(.dark)
}
