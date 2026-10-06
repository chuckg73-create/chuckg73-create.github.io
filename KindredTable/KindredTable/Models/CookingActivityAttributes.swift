import ActivityKit
import Foundation

/// Shared type between the main app (which starts/updates the activity) and
/// the widget extension (which renders it). Both copies must stay identical.
struct CookingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stepNumber: Int
        var totalSteps: Int
        var stepText: String
        var timerEnd: Date?
        var recipeName: String
    }
    var recipeName: String
}
