import Foundation
import Observation

/// Drives the recipe feed: requests suggestions from the Gemini service and
/// exposes loading / error state to the view.
@MainActor
@Observable
final class RecipeFeedModel {

    enum Phase: Equatable {
        case idle
        case loading
        case loaded([Recipe])
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// True when results are the offline samples (no API key configured).
    private(set) var usingSamples = false
    private(set) var lastUpdated: Date?

    private let service: GeminiRecipeService

    init(service: GeminiRecipeService = GeminiRecipeService()) {
        self.service = service
    }

    var recipes: [Recipe] {
        if case .loaded(let list) = phase { return list }
        return []
    }

    var isLoading: Bool { phase == .loading }

    func loadIfNeeded(ingredients: [Ingredient], profile: TasteProfile, servings: Int? = nil, special: Bool = false, tasteFeedback: String? = nil, useUpItems: [String] = []) async {
        if case .loaded = phase { return }
        await refresh(ingredients: ingredients, profile: profile, servings: servings, special: special, tasteFeedback: tasteFeedback, useUpItems: useUpItems)
    }

    func refresh(ingredients: [Ingredient], profile: TasteProfile, servings: Int? = nil, special: Bool = false, tasteFeedback: String? = nil, useUpItems: [String] = []) async {
        phase = .loading
        usingSamples = !AppConfig.hasGeminiKey
        do {
            let recipes = try await service.suggestRecipes(from: ingredients, profile: profile, servings: servings, special: special, tasteFeedback: tasteFeedback, useUpItems: useUpItems)
            lastUpdated = nowStamp()
            phase = .loaded(recipes)
        } catch let error as RecipeServiceError {
            phase = .failed(error.errorDescription ?? "Something went wrong.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// `Date()` is unavailable in some sandboxed contexts used for testing; wrap
    /// it so the model stays easy to reason about.
    private func nowStamp() -> Date { Date() }
}
