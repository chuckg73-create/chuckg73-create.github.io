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
        case batch([Recipe])
        case failed(String)
    }

    @State private var phase: Phase = .choose
    @State private var showCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var scanProgress: (done: Int, total: Int)?
    @State private var attribution = ""
    @State private var story = ""
    @State private var titleDraft = ""
    @State private var urlText = ""
    /// Multiple photos just picked, awaiting the cook's answer to "separate
    /// recipes, or pages of one?" before we know how to read them.
    @State private var pendingPageImages: [UIImage]?
    @FocusState private var urlFocused: Bool

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
                        case .batch(let recipes): batchState(recipes)
                        case .failed(let message): failedState(message)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add a recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in read(image) }.ignoresSafeArea()
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPickedPhotos(items) }
            }
            .confirmationDialog(
                "Separate recipes, or pages of the same one?",
                isPresented: Binding(get: { pendingPageImages != nil }, set: { if !$0 { pendingPageImages = nil } }),
                titleVisibility: .visible
            ) {
                Button("Pages of the same recipe") {
                    if let images = pendingPageImages { readAsOneRecipe(images) }
                    pendingPageImages = nil
                }
                Button("Separate recipes") {
                    if let images = pendingPageImages { readBatch(images) }
                    pendingPageImages = nil
                }
                Button("Cancel", role: .cancel) { pendingPageImages = nil }
            } message: {
                Text("e.g. ingredients on one card and directions on another — pick \u{201C}pages of the same recipe\u{201D} so they read as one.")
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
                Text("Snap a photo of Mom's recipe card or a clipping, or paste a link from any recipe site. KindredTable reads it in — ingredients, steps and all — so you can cook and scale it like any other.")
                    .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    .multilineTextAlignment(.center)
            }

            KindredCard {
                VStack(spacing: 14) {
                    KindredButton(title: "Take a photo", systemImage: "camera.fill") { showCamera = true }
                    PhotosPicker(selection: $photoItems,
                                 maxSelectionCount: 15,
                                 selectionBehavior: .ordered,
                                 matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose photos").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(KindredTheme.text)
                        .background(KindredTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(KindredTheme.hairline, lineWidth: 1))
                    }
                    Label("Pick several cards at once — we'll read them all in. Works best flat, well-lit, whole card in frame.",
                          systemImage: "square.stack.3d.up.fill")
                        .font(.caption).foregroundStyle(KindredTheme.faint)

                    HStack(spacing: 10) {
                        Rectangle().fill(KindredTheme.hairline).frame(height: 1)
                        Text("or").font(.caption).foregroundStyle(KindredTheme.faint)
                        Rectangle().fill(KindredTheme.hairline).frame(height: 1)
                    }
                    .padding(.vertical, 2)

                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "link").foregroundStyle(KindredTheme.accent)
                            TextField("Paste a recipe link", text: $urlText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .submitLabel(.go)
                                .focused($urlFocused)
                                .onSubmit(importFromLink)
                                .foregroundStyle(KindredTheme.text)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(KindredTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(KindredTheme.hairline, lineWidth: 1))

                        Button(action: importFromLink) {
                            Text("Import from link").fontWeight(.semibold)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .foregroundStyle(.white)
                                .background(urlText.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? AnyShapeStyle(KindredTheme.card)
                                            : AnyShapeStyle(KindredTheme.brandGradient),
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var readingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text(scanProgress.map { "Reading recipe \($0.done) of \($0.total)…" } ?? "Reading your recipe…")
                .font(.headline).foregroundStyle(KindredTheme.text)
            Text("Transcribing the ingredients and steps exactly as written.")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private func batchState(_ recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Read \(recipes.count) recipe\(recipes.count == 1 ? "" : "s")", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.mint)
            Text("Save them all to your cookbook — you can fine-tune each one (whose it is, a memory) later.")
                .font(.caption).foregroundStyle(KindredTheme.subtext)

            ForEach(recipes) { recipe in
                HStack(spacing: 12) {
                    Image(systemName: "book.pages.fill")
                        .foregroundStyle(KindredTheme.coral).frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.title).font(.subheadline.weight(.semibold))
                            .foregroundStyle(KindredTheme.text).lineLimit(1)
                        Text("\(recipe.ingredients.count) ingredients · \(recipe.steps.count) steps · Serves \(recipe.servings)")
                            .font(.caption).foregroundStyle(KindredTheme.faint)
                    }
                    Spacer()
                }
                .padding(12)
                .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))
            }

            KindredButton(title: "Save \(recipes.count) to cookbook", systemImage: "tray.and.arrow.down.fill") {
                saveBatch(recipes)
            }
            Button("Choose different photos") { phase = .choose }
                .font(.subheadline).foregroundStyle(KindredTheme.accent)
                .frame(maxWidth: .infinity)
        }
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
                    Divider().overlay(KindredTheme.hairline)
                    field(label: "A memory (optional)") {
                        TextField("e.g. Mom made this every Christmas Eve", text: $story, axis: .vertical)
                            .lineLimit(1...3)
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

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run { photoItems = [] }

        // Load the chosen images.
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        guard !images.isEmpty else {
            await MainActor.run { phase = .failed("Those photos couldn't be opened. Try again.") }
            return
        }
        // A single card keeps the rich single-recipe review (attribution + memory).
        if images.count == 1 {
            await MainActor.run { read(images[0]) }
            return
        }

        // Multiple photos could be several different recipes, or several pages
        // of ONE recipe (ingredients on one card, directions on another) —
        // ask, rather than guessing and silently splitting a family recipe in two.
        await MainActor.run { pendingPageImages = images }
    }

    /// Reads each photo as its own separate recipe (a box of different cards).
    private func readBatch(_ images: [UIImage]) {
        Task {
            await MainActor.run { phase = .reading; scanProgress = (0, images.count) }
            let service = self.service
            var recipes: [Recipe] = []
            var done = 0
            var start = 0
            let chunk = 3
            while start < images.count {
                let slice = Array(images[start..<min(start + chunk, images.count)])
                let read = await withTaskGroup(of: Recipe?.self) { group -> [Recipe] in
                    for img in slice {
                        group.addTask {
                            guard let jpeg = img.jpegForUpload() else { return nil }
                            return try? await service.importRecipe(from: jpeg)
                        }
                    }
                    var out: [Recipe] = []
                    for await r in group { if let r { out.append(r) } }
                    return out
                }
                recipes.append(contentsOf: read)
                done += slice.count
                let d = done
                await MainActor.run { scanProgress = (d, images.count) }
                start += chunk
            }

            let result = recipes
            await MainActor.run {
                scanProgress = nil
                if result.isEmpty {
                    phase = .failed("Couldn't read those. Try clearer, flatter photos with the whole card in frame.")
                } else {
                    phase = .batch(result)
                }
            }
        }
    }

    /// Reads every photo TOGETHER as one recipe (ingredients on one page,
    /// directions on another) — the single-recipe review, same as one photo.
    private func readAsOneRecipe(_ images: [UIImage]) {
        Task {
            await MainActor.run { phase = .reading; scanProgress = nil }
            let jpegs = images.compactMap { $0.jpegForUpload() }
            guard !jpegs.isEmpty else {
                await MainActor.run { phase = .failed("Those photos couldn't be prepared. Try again.") }
                return
            }
            do {
                let recipe = try await service.importRecipe(fromPages: jpegs)
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

    private func saveBatch(_ recipes: [Recipe]) {
        // Dismiss before mutating the store so the @Observable re-render fires
        // after the sheet binding is already nil, preventing the "sheet won't
        // reopen" race where activeSheet flickers non-nil during dismissal.
        dismiss()
        for var recipe in recipes {
            recipe.source = .imported
            cookbook.add(recipe)
            if recipe.imageURL.trimmingCharacters(in: .whitespaces).isEmpty,
               RecipeImageService.shared.isAvailable {
                let forPhoto = recipe
                Task.detached { _ = await RecipeImageService.shared.image(for: forPhoto) }
            }
        }
    }

    private func importFromLink() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let url = WebRecipeFetcher.normalize(trimmed) else {
            phase = .failed(WebRecipeFetcher.FetchError.badURL.errorDescription ?? "Invalid link.")
            return
        }
        urlFocused = false
        phase = .reading
        Task {
            do {
                let page = try await WebRecipeFetcher.fetch(from: url)
                var recipe = try await service.importRecipe(fromWebText: page.text,
                                                            sourceLabel: WebRecipeFetcher.sourceLabel(for: url))
                recipe.imageURL = page.imageURL
                await MainActor.run {
                    titleDraft = recipe.title
                    attribution = recipe.sourceNote   // prefilled with the site; editable
                    phase = .review(recipe)
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run { phase = .failed(message) }
            }
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
        toSave.story = story.trimmingCharacters(in: .whitespacesAndNewlines)

        // Dismiss before mutating the store so the @Observable re-render fires
        // after the sheet binding is already nil, preventing the "sheet won't
        // reopen" race where activeSheet flickers non-nil during dismissal.
        dismiss()

        cookbook.add(toSave)

        // Warm an AI photo for recipes that arrived without one (a photographed
        // recipe card like Grandma's peanut butter fudge), so the cookbook card
        // is photo-rich immediately instead of waiting for the first detail open.
        if toSave.imageURL.trimmingCharacters(in: .whitespaces).isEmpty,
           RecipeImageService.shared.isAvailable {
            let recipeForPhoto = toSave
            Task.detached { _ = await RecipeImageService.shared.image(for: recipeForPhoto) }
        }
    }
}
