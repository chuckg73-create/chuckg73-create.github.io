import SwiftUI
import PhotosUI
import UIKit

/// The main capture screen: photograph the fridge/pantry, run on-device Vision
/// recognition, and route the results into an editable review sheet.
struct CaptureView: View {
    @Environment(PantryStore.self) private var pantry
    var goToPantry: () -> Void

    private let recognizer = VisionIngredientRecognizer()
    private let geminiService = GeminiRecipeService()

    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isRecognizing = false
    @State private var recognized: [Ingredient] = []
    @State private var showReview = false
    @State private var errorMessage: String?
    @State private var lastImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        captureCard
                        howItWorks
                    }
                    .padding(20)
                }
            }
            .navigationTitle("KindredKitchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ProfileToolbarButton() } }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in handle(image) }
                    .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task { await loadPickedPhoto(newValue) }
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

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KindredTheme.brandGradient)
                    .frame(width: 108, height: 108)
                    .shadow(color: KindredTheme.accent.opacity(0.4), radius: 24, y: 10)
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            Text("What's in your kitchen?")
                .font(.title2).fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Snap your fridge or pantry. KindredKitchen identifies the ingredients, then suggests meals matched to your taste.")
                .font(.subheadline)
                .foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var captureCard: some View {
        KindredCard {
            VStack(spacing: 14) {
                if isRecognizing {
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large).tint(KindredTheme.accent)
                        Text("Identifying ingredients…")
                            .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                } else {
                    KindredButton(title: "Take a photo", systemImage: "camera.fill") {
                        showCamera = true
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from library").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(KindredTheme.text)
                        .background(KindredTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(KindredTheme.hairline, lineWidth: 1))
                    }
                    Label(
                        AppConfig.hasGeminiKey
                            ? "Your photo is sent securely to identify ingredients."
                            : "Photos are analysed on-device and never uploaded.",
                        systemImage: AppConfig.hasGeminiKey ? "sparkles" : "lock.fill"
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

    private func handle(_ image: UIImage) {
        lastImage = image
        recognize(image)
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        photoItem = nil
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { handle(image) }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func recognize(_ image: UIImage) {
        isRecognizing = true
        Task {
            do {
                let found: [Ingredient]
                if AppConfig.hasGeminiKey, let jpeg = image.jpegForUpload() {
                    // Vision model reads the photo far more accurately.
                    found = try await geminiService.identifyIngredients(in: jpeg)
                } else {
                    // Offline fallback: on-device Apple Vision classifier.
                    found = try await recognizer.recognizeIngredients(in: image)
                }
                await MainActor.run {
                    isRecognizing = false
                    recognized = found      // may be empty; the sheet still allows manual add
                    showReview = true
                }
            } catch {
                await MainActor.run {
                    isRecognizing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    CaptureView(goToPantry: {})
        .environment(PantryStore(seed: SampleData.ingredients))
        .environment(ProfileStore(seed: .starter))
        .preferredColorScheme(.dark)
}
