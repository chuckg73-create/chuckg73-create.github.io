import SwiftUI
import PhotosUI
import UIKit

/// Scan the kitchen: photograph your counter or cabinet and Kindred Kitchen
/// identifies the appliances you own, so recipe steps get written for your exact
/// gear (your rice cooker, air fryer, smoker) instead of a hand-typed list.
struct EquipmentScanView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()

    enum Phase: Equatable {
        case choose
        case reading
        case review([String])
        case failed(String)
    }

    @State private var phase: Phase = .choose
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .choose: chooseState
                        case .reading: readingState
                        case .review(let found): reviewState(found)
                        case .failed(let message): failedState(message)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Scan my kitchen")
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

    private var chooseState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(KindredTheme.brandGradient)
                        .frame(width: 96, height: 96)
                        .shadow(color: KindredTheme.accent.opacity(0.4), radius: 20, y: 8)
                    Image(systemName: "cooktop.fill")
                        .font(.system(size: 40, weight: .semibold)).foregroundStyle(.white)
                }
                .padding(.top, 8)
                Text("What's in your kitchen?")
                    .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                Text("Snap your counter or open a cabinet. Kindred Kitchen spots your appliances so every recipe's steps are written for the gear you actually own.")
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
                    Label("Take a few — one of the counter, one of a cabinet — and add them one at a time.",
                          systemImage: "lightbulb.fill")
                        .font(.caption).foregroundStyle(KindredTheme.faint)
                }
            }
        }
    }

    private var readingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text("Looking at your kitchen…")
                .font(.headline).foregroundStyle(KindredTheme.text)
            Text("Spotting the appliances that change how food is cooked.")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private func reviewState(_ found: [String]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if found.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 40)).foregroundStyle(KindredTheme.amber)
                    Text("Didn't spot any appliances")
                        .font(.headline).foregroundStyle(KindredTheme.text)
                    Text("Try a clearer photo of your countertop or an open cabinet.")
                        .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                        .multilineTextAlignment(.center)
                    KindredButton(title: "Try another photo", systemImage: "camera.fill") { reset() }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                Label("Tap to confirm what you'd like to add", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.mint)

                KindredCard {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)],
                              alignment: .leading, spacing: 8) {
                        ForEach(found, id: \.self) { item in
                            let isOn = selected.contains(item)
                            let alreadyHave = EquipmentMatcher.contains(profileStore.profile.equipment, item)
                            Button {
                                if isOn { selected.remove(item) } else { selected.insert(item) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                    Text(item).font(.subheadline.weight(.medium))
                                    if alreadyHave {
                                        Text("· have").font(.caption2).foregroundStyle(KindredTheme.faint)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .foregroundStyle(isOn ? Color.white : KindredTheme.subtext)
                                .background(isOn ? AnyShapeStyle(KindredTheme.brandGradient)
                                                 : AnyShapeStyle(KindredTheme.card), in: Capsule())
                                .overlay(Capsule().stroke(isOn ? Color.clear : KindredTheme.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                KindredButton(title: selected.isEmpty ? "Select what to add" : "Add \(selected.count) to my kitchen",
                              systemImage: "plus.circle.fill") {
                    addSelected()
                }
                .disabled(selected.isEmpty)
                Button("Scan another photo") { reset() }
                    .font(.subheadline).foregroundStyle(KindredTheme.accent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44)).foregroundStyle(KindredTheme.amber)
            Text("Couldn't scan that")
                .font(.headline).foregroundStyle(KindredTheme.text)
            Text(message)
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
            KindredButton(title: "Try again", systemImage: "camera.fill") { reset() }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: Actions

    private func reset() { selected = []; phase = .choose }

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
                let found = try await service.identifyEquipment(in: jpeg)
                await MainActor.run {
                    // Pre-select everything the cook doesn't already have
                    // (brand/synonym-aware, so "Smoker" ≠ new if they have "Traeger").
                    selected = Set(found.filter { !EquipmentMatcher.contains(profileStore.profile.equipment, $0) })
                    phase = .review(found)
                }
            } catch {
                let message = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                await MainActor.run { phase = .failed(message) }
            }
        }
    }

    private func addSelected() {
        for item in selected where !EquipmentMatcher.contains(profileStore.profile.equipment, item) {
            profileStore.profile.equipment.append(item)
        }
        dismiss()
    }
}
