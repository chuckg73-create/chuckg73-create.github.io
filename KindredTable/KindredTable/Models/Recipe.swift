import Foundation

/// A meal suggestion produced by the recipe-matching model.
struct Recipe: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var summary: String
    var mealType: MealType
    /// Ingredients drawn from the user's pantry.
    var usesOnHand: [String]
    /// Small number of extra items the user would need to buy.
    var needsToBuy: [String]
    var steps: [String]
    var cookMinutes: Int
    var difficulty: Difficulty
    var tags: [String]
    /// 0…100 fit against the pantry + taste profile, as scored by the model.
    var matchScore: Int
    /// Short note explaining why this suits the user's taste profile.
    var whyYoullLikeIt: String

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        mealType: MealType = .dinner,
        usesOnHand: [String] = [],
        needsToBuy: [String] = [],
        steps: [String] = [],
        cookMinutes: Int = 20,
        difficulty: Difficulty = .easy,
        tags: [String] = [],
        matchScore: Int = 0,
        whyYoullLikeIt: String = ""
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.mealType = mealType
        self.usesOnHand = usesOnHand
        self.needsToBuy = needsToBuy
        self.steps = steps
        self.cookMinutes = cookMinutes
        self.difficulty = difficulty
        self.tags = tags
        self.matchScore = matchScore
        self.whyYoullLikeIt = whyYoullLikeIt
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable, Hashable {
    case breakfast, lunch, dinner, snack, dessert

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        case .dessert: return "birthday.cake.fill"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable, Hashable {
    case easy, medium, involved

    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .involved: return "Involved"
        }
    }
}
