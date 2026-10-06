import Foundation
import Observation

/// Owns the user's taste profile, persisted locally.
@Observable
final class ProfileStore {

    var profile: TasteProfile {
        didSet { persist() }
    }

    /// Whether the user has completed the one-time taste-profile setup.
    /// Persisted as a single-element array because a bare `Bool` is not valid
    /// top-level JSON.
    var hasOnboarded: Bool {
        didSet { LocalStore.save([hasOnboarded], to: onboardFileName) }
    }

    /// Raw JPEG data for the user's profile photo, stored as a separate file
    /// so it doesn't bloat the JSON profile.
    private(set) var photoData: Data?

    private let fileName = "taste_profile.json"
    private let onboardFileName = "onboarded.json"

    private var photoURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("profile_photo.jpg")
    }

    init(seed: TasteProfile? = nil) {
        if let seed {
            profile = seed
            hasOnboarded = true
        } else {
            profile = LocalStore.load(TasteProfile.self, from: fileName) ?? .starter
            hasOnboarded = LocalStore.load([Bool].self, from: onboardFileName)?.first ?? false
        }
        photoData = try? Data(contentsOf: photoURL)
    }

    func savePhoto(_ data: Data) {
        try? data.write(to: photoURL)
        photoData = data
    }

    private func persist() {
        LocalStore.save(profile, to: fileName)
        LocalStore.backupToCloud(fileName)
    }
}
