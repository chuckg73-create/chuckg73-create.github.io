import SwiftUI
import PhotosUI
import UIKit

/// Add one of your own recipes to the cookbook by photographing it — a
/// handwritten card, a clipping, a printout. Gemini reads it into a full recipe,
/// you confirm whose it is, and it's saved beside the app's finds.
struct CookbookImportView: View {
    @Environment(SavedRecipeStore.self) private var cookbook
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()

    enum Phase: Equatable {
        case choose
        case reading
        case review(Recipe)
        case failed(String)
    }

    @State private var phase: Phase = .choose
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var attribution = ""
    @State private var titleDraft = ""

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .choose:  chooseState
                        case .reading: readingState
                        case .review(let recipe): reviewState(recipe)
                        case .failed(let message): failedState(message)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add a recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in read(image) }.ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await loadPicked(item) }
            }
        }
    }

    // MARK: States

    private var chooseState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(KindredTheme.brandGradient)
                        .frame(width: 96, height: 96)
                        .shadow(color: KindredTheme.accent.opacity(0.4), radius: 20, y: 8)
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 40, weight: .semibold)).foregroundStyle(.white)
                }
                .padding(.top, 8)
                Text("Bring your recipes in")
                    .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                Text("Snap a photo of Mom's recipe card, a magazine clipping, or a printout. Kindred Kitchen reads it in — ingredients, steps and all — so you can cook and scale it like any other.")
                    .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }

            KindredCard {
                VStack(spacing: 14) {
                    KindredButton(title: "Take a photo", systemImage: "camera.fill") { showCamera = true }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from library").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(KindredTheme.text)
                        .background(KindredTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(KindredTheme.hairline, lineWidth: 1))
                    }
                    Label("Works best on a flat, well-lit recipe with the whole card in frame.",
                          systemImage: "lightbulb.fill")
                        .font(.caption).foregroundStyle(KindredTheme.faint)
                }
            }
        }
    }

    private var readingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text("Reading your recipe…")
                .font(.headline).foregroundStyle(KindredTheme.text)
            Text("Transcribing the ingredients and steps exactly as written.")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private func reviewState(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Got it — here's what we read", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.mint)

            KindredCard {
                VStack(alignment: .leading, spacing: 14) {
                    field(label: "Recipe name") {
                        TextField("Recipe name", text: $titleDraft)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(KindredTheme.text)
                    }
                    Divider().overlay(KindredTheme.hairline)
                    field(label: "Whose recipe? (optional)") {
                        TextField("e.g. Mom, Grandma Rose", text: $attribution)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(KindredTheme.text)
                    }
                }
            }

            KindredCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        Label("\(recipe.ingredients.count) ingredients", systemImage: "list.bullet")
                        Label("\(recipe.steps.count) steps", systemImage: "number")
                        Label("Serves \(recipe.servings)", systemImage: "person.2.fill")
                    }
                    .font(.caption).foregroundStyle(KindredTheme.faint)

                    if let first = recipe.ingredients.first {
                        Text("Starts with: \(first.display)…")
                            .font(.caption).foregroundStyle(KindredTheme.subtext)
                    }
                    Text("You can fine-tune anything after saving.")
                        .font(.caption2).foregroundStyle(KindredTheme.faint)
                }
            }

            KindredButton(title: "Save to cookbook", systemImage: "tray.and.arrow.down.fill") {
                save(recipe)
            }
            Button("Try another photo") { phase = .choose }
                .font(.subheadline).foregroundStyle(KindredTheme.accent)
                .frame(maxWidth: .infinity)
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 44)).foregroundStyle(KindredTheme.amber)
            Text("Couldn't read that one")
                .font(.headline).foregroundStyle(KindredTheme.text)
            Text(message)
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
            KindredButton(title: "Try again", systemImage: "camera.fill") { phase = .choose }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold)).foregroundStyle(KindredTheme.faint)
                .tracking(0.5)
            content()
        }
    }

    // MARK: Actions

    private func loadPicked(_ item: PhotosPickerItem) async {
        photoItem = nil
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { read(image) }
            }
        } catch {
            await MainActor.run { phase = .failed(error.localizedDescription) }
        }
    }

    private func read(_ image: UIImage) {
        guard let jpeg = image.jpegForUpload() else {
            phase = .failed("That image couldn't be prepared. Try another photo.")
            return
        }
        phase = .reading
        Task {
            do {
                let recipe = try await service.importRecipe(from: jpeg)
                await MainActor.run {
                    titleDraft = recipe.title
                    attribution = ""
                    phase = .review(recipe)
                }
            } catch {
                let message = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                await MainActor.run { phase = .failed(message) }
            }
        }
    }

    private func save(_ recipe: Recipe) {
        var toSave = recipe
        let name = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { toSave.title = name }
        toSave.sourceNote = attribution.trimmingCharacters(in: .whitespacesAndNewlines)
        cookbook.add(toSave)
        dismiss()
    }
}
