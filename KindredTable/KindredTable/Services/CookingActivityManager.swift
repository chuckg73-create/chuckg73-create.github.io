import ActivityKit
import Foundation

/// Manages the Live Activity that pins the active cook session to the
/// Lock Screen and Dynamic Island. No-ops gracefully on older OS versions
/// or when the user has disabled Live Activities.
@MainActor
final class CookingActivityManager {

    static let shared = CookingActivityManager()
    private init() {}

    private var activity: Activity<CookingActivityAttributes>?

    func start(recipe: Recipe) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()   // clear any stale activity first

        let initial = CookingActivityAttributes.ContentState(
            stepNumber: 1,
            totalSteps: max(1, recipe.steps.count),
            stepText: recipe.steps.first.map { truncate($0) } ?? recipe.title,
            timerEnd: nil,
            recipeName: recipe.title
        )
        let attrs = CookingActivityAttributes(recipeName: recipe.title)

        activity = try? Activity.request(
            attributes: attrs,
            content: .init(state: initial, staleDate: nil),
            pushType: nil
        )
    }

    func update(stepNumber: Int, totalSteps: Int, stepText: String, timerEnd: Date?) {
        guard let activity else { return }
        let state = CookingActivityAttributes.ContentState(
            stepNumber: stepNumber,
            totalSteps: totalSteps,
            stepText: truncate(stepText),
            timerEnd: timerEnd,
            recipeName: activity.attributes.recipeName
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        let final = activity.contentState
        Task {
            await activity.end(.init(state: final, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }

    private func truncate(_ text: String) -> String {
        text.count > 80 ? String(text.prefix(77)) + "..." : text
    }
}
