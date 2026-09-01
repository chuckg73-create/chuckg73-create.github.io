import SwiftUI
import PhotosUI
import UIKit

/// The main capture screen: photograph the fridge/pantry, run on-device Vision
/// recognition, and route the results into an editable review sheet.
struct CaptureView: View {
    @Environment(PantryStore.self) private var pantry
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(MealPlanStore.self) private var mealPlan
    var goToPantry: () -> Void
    var goToRecipes: () -> Void = {}
    var goToCookbook: () -> Void = {}

    private let recognizer = VisionIngredientRecognizer()
    private let geminiService = GeminiRecipeService()

    @State private var showCamera = false
    @State private var showChef = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isRecognizing = false
    /// Progress while scanning a batch of chosen photos (done, total).
    @State private var scanProgress: (done: Int, total: Int)?
    @State private var recognized: [Ingredient] = []
    @State private var showReview = false
    @State private var errorMessage: String?
    @State private var lastImage: UIImage?

    /// The cook's most recent recipes, newest first, for the "jump back in" row.
    private var recentRecipes: [Recipe] { Array(saved.saved.prefix(10)) }

    /// The 5pm moment: what's for dinner. A meal planned for today wins; otherwise,
    /// in the late afternoon/evening, feature a dinner from the cookbook.
    private var tonight: (recipe: Recipe, label: String)? {
        let today = mealPlan.meals(on: Date())
        if let planned = today.first(where: { $0.recipe.mealType == .dinner }) ?? today.first {
            return (planned.recipe, "Planned for tonight")
        }
        guard Calendar.current.component(.hour, from: Date()) >= 16 else { return nil }
        let dinners = saved.saved.filter { $0.mealType == .dinner }
        let pool = dinners.isEmpty ? saved.saved : dinners
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return (pool[day % pool.count], "Tonight’s idea")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        greeting
                        chefEntry
                        if let tonight { tonightCard(tonight.recipe, label: tonight.label) }
                        captureCard
                        if !recentRecipes.isEmpty { jumpBackIn }
                        quickLinks
                        if recentRecipes.isEmpty { howItWorks }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("KindredTable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ProfileToolbarButton() } }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in handle(image) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showChef) { ChefView() }
            .onChange(of: photoItems) { _, newValue in
                guard !newValue.isEmpty else { return }
                Task { await loadPickedPhotos(newValue) }
            }
            .sheet(isPresented: $showReview) {
                IngredientReviewSheet(
                    image: lastImage,
                    detected: recognized,
                    onConfirm: { chosen in
                        pantry.merge(chosen)
                        showReview = false
                        goToPantry()
                    }
                )
            }
            .alert(
                "Couldn't scan that",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sections

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.timeGreeting)
                .font(.largeTitle).fontWeight(.heavy)
                .foregroundStyle(KindredTheme.text)
            Text(recentRecipes.isEmpty
                 ? "Photograph your fridge and cook what matches you."
                 : "What sounds good? Snap your kitchen or pick up where you left off.")
                .font(.subheadline)
                .foregroundStyle(KindredTheme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    /// Entry to the conversational chef.
    private var chefEntry: some View {
        Button { showChef = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask the kitchen").font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.text)
                    Text("“Plan me an easy week, no chicken”").font(.caption).foregroundStyle(KindredTheme.subtext)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(KindredTheme.faint)
            }
            .padding(14)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KindredTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Time-aware greeting (uses the device clock at render time).
    private static var timeGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Late-night kitchen"
        }
    }

    private func tonightCard(_ recipe: Recipe, label: String) -> some View {
        NavigationLink { RecipeDetailView(recipe: recipe) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    RecipeHeroImage(recipe: recipe, height: 180, glyphSize: 46)
                    LinearGradient(colors: [.clear, .black.opacity(0.72)],
                                   startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Label(label.uppercased(), systemImage: "moon.stars.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(KindredTheme.accent)
                        Text(recipe.title)
                            .font(.title3).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text("\(recipe.totalMinutes) min · tap to cook")
                            .font(.caption).foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous).stroke(KindredTheme.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var jumpBackIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(label: "Jump back in")
                Spacer()
                Button("Cookbook", action: goToCookbook)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KindredTheme.accent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recentRecipes) { recipe in
                        NavigationLink { RecipeDetailView(recipe: recipe) } label: {
                            recentCard(recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private func recentCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipeHeroImage(recipe: recipe, height: 116, glyphSize: 34)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(recipe.title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(KindredTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(recipe.totalMinutes) min · \(recipe.mealType.title)")
                .font(.caption).foregroundStyle(KindredTheme.faint)
        }
        .frame(width: 168, alignment: .leading)
    }

    private var quickLinks: some View {
        HStack(spacing: 12) {
            quickTile("Today's ideas", "sparkles", KindredTheme.accent, action: goToRecipes)
            quickTile("Cookbook", "books.vertical.fill", KindredTheme.amber, action: goToCookbook)
            quickTile("On hand", "list.bullet.rectangle.portrait", KindredTheme.blue, action: goToPantry)
        }
    }

    private func quickTile(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(title)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(KindredTheme.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: KindredTheme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: KindredTheme.corner, style: .continuous).stroke(KindredTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var captureCard: some View {
        KindredCard {
            VStack(spacing: 14) {
                if isRecognizing {
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large).tint(KindredTheme.accent)
                        Text(scanStatusText)
                            .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                } else {
                    KindredButton(title: "Take a photo", systemImage: "camera.fill") {
                        showCamera = true
                    }
                    PhotosPicker(selection: $photoItems,
                                 maxSelectionCount: 30,
                                 selectionBehavior: .ordered,
                                 matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose photos").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(KindredTheme.text)
                        .background(KindredTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(KindredTheme.hairline, lineWidth: 1))
                    }
                    Label(
                        AppConfig.hasGeminiKey
                            ? "Pick several at once — fridge, freezer, pantry — and we'll combine them into one list."
                            : "Photos are analysed on-device and never uploaded.",
                        systemImage: AppConfig.hasGeminiKey ? "square.stack.3d.up.fill" : "lock.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(KindredTheme.faint)
                    .padding(.top, 2)
                }
            }
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(label: "How it works")
            step(1, "Snap", "Photograph your open fridge or a pantry shelf.", "camera.viewfinder")
            step(2, "Review", "Edit the detected ingredients — add or remove anything.", "checklist")
            step(3, "Cook", "Get daily meal ideas matched to what you have and love.", "fork.knife")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func step(_ n: Int, _ title: String, _ body: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(KindredTheme.accent)
                .frame(width: 38, height: 38)
                .background(KindredTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(n). \(title)").font(.subheadline).fontWeight(.semibold)
                Text(body).font(.caption).foregroundStyle(KindredTheme.subtext)
            }
            Spacer()
        }
    }

    // MARK: Actions

    private var scanStatusText: String {
        if let p = scanProgress, p.total > 1 {
            return p.done == 0 ? "Reading \(p.total) photos…" : "Scanned \(p.done) of \(p.total)…"
        }
        return "Identifying ingredients…"
    }

    /// Single image from the camera — route through the same batch path.
    private func handle(_ image: UIImage) {
        lastImage = image
        recognizeBatch([image])
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run { photoItems = [] }
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        guard !images.isEmpty else {
            await MainActor.run { errorMessage = "Those photos couldn't be opened. Try again." }
            return
        }
        await MainActor.run { recognizeBatch(images) }
    }

    /// Recognize ingredients across one or many photos and merge into a single,
    /// de-duplicated list — so a cook can capture the fridge, freezer and pantry
    /// in one pass instead of scanning shelf by shelf. Runs in small concurrent
    /// batches with progress; a photo that fails is skipped, not fatal.
    private func recognizeBatch(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        isRecognizing = true
        scanProgress = images.count > 1 ? (0, images.count) : nil

        let service = geminiService
        let visionRecognizer = recognizer
        let hasKey = AppConfig.hasGeminiKey

        Task {
            func detect(_ image: UIImage) async -> [Ingredient] {
                do {
                    if hasKey, let jpeg = image.jpegForUpload() {
                        return try await service.identifyIngredients(in: jpeg)
                    }
                    return try await visionRecognizer.recognizeIngredients(in: image)
                } catch {
                    return []   // skip a photo that fails; keep the rest
                }
            }

            var combined: [Ingredient] = []
            var seen = Set<String>()
            var processed = 0
            let chunkSize = 5
            var start = 0
            while start < images.count {
                let chunk = Array(images[start..<min(start + chunkSize, images.count)])
                let results = await withTaskGroup(of: [Ingredient].self) { group -> [[Ingredient]] in
                    for img in chunk { group.addTask { await detect(img) } }
                    var out: [[Ingredient]] = []
                    for await found in group { out.append(found) }
                    return out
                }
                for found in results {
                    for ing in found where seen.insert(ing.name.lowercased()).inserted {
                        combined.append(ing)
                    }
                }
                processed += chunk.count
                let done = processed
                let total = images.count
                await MainActor.run { if total > 1 { scanProgress = (done, total) } }
                start += chunkSize
            }

            let result = combined
            let first = images.first
            await MainActor.run {
                isRecognizing = false
                scanProgress = nil
                recognized = result      // may be empty; the sheet still allows manual add
                lastImage = first
                showReview = true
            }
        }
    }
}

#Preview {
    CaptureView(goToPantry: {})
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(SavedRecipeStore(seed: Array(SampleData.recipes.prefix(3))))
        .environment(ProfileStore(seed: .starter))
        .environment(HouseholdStore())
        .environment(GroceryStore())
        .environment(MealPlanStore())
        .environment(TasteFeedbackStore())
        .environment(RecipeNotesStore())
        .preferredColorScheme(.dark)
}
