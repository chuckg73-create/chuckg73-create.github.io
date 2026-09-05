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

    private let fileName = "taste_profile.json"
    private let onboardFileName = "onboarded.json"

    init(seed: TasteProfile? = nil) {
        if let seed {
            profile = seed
            hasOnboarded = true
        } else {
            profile = LocalStore.load(TasteProfile.self, from: fileName) ?? .starter
            hasOnboarded = LocalStore.load([Bool].self, from: onboardFileName)?.first ?? false
        }
    }

    private func persist() {
        LocalStore.save(profile, to: fileName)
        LocalStore.backupToCloud(fileName)
    }
}
