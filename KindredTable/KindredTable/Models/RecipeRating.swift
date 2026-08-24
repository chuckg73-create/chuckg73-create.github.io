import Foundation

/// How a cook felt about a dish they actually made.
enum RecipeVerdict: String, Codable, Hashable, CaseIterable, Identifiable {
    case loved, liked, disliked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loved: return "Loved it"
        case .liked: return "It was okay"
        case .disliked: return "Not for me"
        }
    }

    var systemImage: String {
        switch self {
        case .loved: return "heart.fill"
        case .liked: return "hand.thumbsup"
        case .disliked: return "hand.thumbsdown"
        }
    }
}

/// A recorded rating for a dish the cook made — the raw signal the taste engine
/// learns from.
struct RecipeRating: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var recipeTitle: String
    var verdict: RecipeVerdict
    var tags: [String]        // cuisines / descriptors, for generalizing taste
    var mealType: String
    var date: Date
}
