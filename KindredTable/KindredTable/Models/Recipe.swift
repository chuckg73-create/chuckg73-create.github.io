import Foundation

/// One line of a recipe's ingredient list, with an amount and whether the cook
/// already has it. Value-hashable (no id) so a decoded recipe equals itself.
struct RecipeIngredient: Codable, Hashable {
    var name: String
    var amount: String   // "2 cups", "1 lb", "to taste", "2"
    var haveIt: Bool     // already in the user's pantry

    /// "2 cups rice" — or just the name when no amount is given.
    var display: String {
        amount.trimmingCharacters(in: .whitespaces).isEmpty ? name : "\(amount) \(name)"
    }
}

/// One entry in a recipe's back-timed cooking schedule: what to do and how many
/// minutes before serving to do it (so "put the turkey in the smoker" can be 240).
struct TimelineTask: Codable, Hashable {
    var task: String
    var minutesBeforeServing: Int
}

/// Where a recipe came from: matched by the app, or added by the cook from a
/// photo of a recipe card (their mom's, a magazine clipping…).
enum RecipeSource: String, Codable, Hashable {
    case app        // suggested / craved / made by KindredTable
    case imported   // photographed & parsed from the cook's own recipe

    var isImported: Bool { self == .imported }
}

/// Rough per-serving nutrition, as estimated by the model. All values are
/// per single serving, so they don't change when the recipe is scaled.
struct NutritionInfo: Codable, Hashable {
    var calories: Int
    var protein: Int   // grams
    var carbs: Int     // grams
    var fat: Int       // grams

    var hasAny: Bool { calories > 0 || protein > 0 || carbs > 0 || fat > 0 }
}

/// A meal suggestion produced by the recipe-matching model.
struct Recipe: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var summary: String
    var mealType: MealType
    /// How this recipe entered the cookbook.
    var source: RecipeSource
    /// Optional attribution for an imported recipe — "Mom's", "Grandma Rose".
    var sourceNote: String
    /// Optional family memory / story for a treasured recipe — "Mom made this
    /// every Christmas Eve." Shown prominently on imported recipes.
    var story: String
    /// Optional hero image URL (e.g. a web recipe's photo). Empty = show the
    /// designed placeholder hero instead.
    var imageURL: String
    /// Full ingredient list with amounts; `haveIt` marks pantry items.
    var ingredients: [RecipeIngredient]
    /// Numbered method steps — written for this cook's equipment where it helps.
    var steps: [String]
    /// Short, practical chef tips / hints.
    var tips: [String]
    /// For imported recipes only: notes KindredTable added when polishing —
    /// gaps the handwriting left out (missing temp, vague "a pinch", an
    /// ingredient never used in the steps). Kept separate from `tips` so the
    /// original recipe and the app's help stay clearly distinct.
    var cooksNotes: [String]
    var servings: Int
    var prepMinutes: Int
    var cookMinutes: Int
    var difficulty: Difficulty
    var tags: [String]
    /// 0…100 fit against the pantry + taste profile, as scored by the model.
    var matchScore: Int
    /// Short note explaining why this suits the user's taste profile.
    var whyYoullLikeIt: String
    /// Optional back-timed cooking schedule for "cook by a time" reminders.
    var timeline: [TimelineTask]
    /// Optional per-serving nutrition estimate.
    var nutrition: NutritionInfo?

    /// Pantry item names — derived from `ingredients`.
    var usesOnHand: [String] { ingredients.filter(\.haveIt).map(\.name) }
    /// Shopping item names — derived from `ingredients`.
    var needsToBuy: [String] { ingredients.filter { !$0.haveIt }.map(\.name) }
    var totalMinutes: Int { max(0, prepMinutes) + max(0, cookMinutes) }

    /// A friendly label for where it came from — used on cards and detail.
    var attribution: String {
        let note = sourceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isImported { return note.isEmpty ? "Your recipe" : "\(note) recipe" }
        return ""
    }

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        mealType: MealType = .dinner,
        source: RecipeSource = .app,
        sourceNote: String = "",
        story: String = "",
        imageURL: String = "",
        ingredients: [RecipeIngredient] = [],
        steps: [String] = [],
        tips: [String] = [],
        cooksNotes: [String] = [],
        servings: Int = 2,
        prepMinutes: Int = 10,
        cookMinutes: Int = 20,
        difficulty: Difficulty = .easy,
        tags: [String] = [],
        matchScore: Int = 0,
        whyYoullLikeIt: String = "",
        timeline: [TimelineTask] = [],
        nutrition: NutritionInfo? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.mealType = mealType
        self.source = source
        self.sourceNote = sourceNote
        self.story = story
        self.imageURL = imageURL
        self.ingredients = ingredients
        self.steps = steps
        self.tips = tips
        self.cooksNotes = cooksNotes
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.difficulty = difficulty
        self.tags = tags
        self.matchScore = matchScore
        self.whyYoullLikeIt = whyYoullLikeIt
        self.timeline = timeline
        self.nutrition = nutrition
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary, mealType, source, sourceNote, story, imageURL, ingredients, steps, tips, cooksNotes
        case servings, prepMinutes, cookMinutes, difficulty, tags, matchScore, whyYoullLikeIt, timeline, nutrition
    }

    private enum LegacyKeys: String, CodingKey {
        case usesOnHand, needsToBuy
    }

    /// Tolerant decode: newer saves carry `ingredients`; older saved recipes had
    /// only `usesOnHand`/`needsToBuy` name arrays (no amounts) — rebuild from
    /// those so nothing in the Saved tab breaks after this upgrade.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        mealType = try c.decodeIfPresent(MealType.self, forKey: .mealType) ?? .dinner
        source = try c.decodeIfPresent(RecipeSource.self, forKey: .source) ?? .app
        sourceNote = try c.decodeIfPresent(String.self, forKey: .sourceNote) ?? ""
        story = try c.decodeIfPresent(String.self, forKey: .story) ?? ""
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        tips = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
        cooksNotes = try c.decodeIfPresent([String].self, forKey: .cooksNotes) ?? []
        servings = try c.decodeIfPresent(Int.self, forKey: .servings) ?? 2
        prepMinutes = try c.decodeIfPresent(Int.self, forKey: .prepMinutes) ?? 0
        cookMinutes = try c.decodeIfPresent(Int.self, forKey: .cookMinutes) ?? 20
        difficulty = try c.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .easy
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        matchScore = try c.decodeIfPresent(Int.self, forKey: .matchScore) ?? 0
        whyYoullLikeIt = try c.decodeIfPresent(String.self, forKey: .whyYoullLikeIt) ?? ""
        timeline = try c.decodeIfPresent([TimelineTask].self, forKey: .timeline) ?? []
        nutrition = try c.decodeIfPresent(NutritionInfo.self, forKey: .nutrition)

        if let list = try c.decodeIfPresent([RecipeIngredient].self, forKey: .ingredients), !list.isEmpty {
            ingredients = list
        } else if let legacy = try? decoder.container(keyedBy: LegacyKeys.self) {
            let have = (try? legacy.decodeIfPresent([String].self, forKey: .usesOnHand)) ?? []
            let buy = (try? legacy.decodeIfPresent([String].self, forKey: .needsToBuy)) ?? []
            ingredients = have.map { RecipeIngredient(name: $0, amount: "", haveIt: true) }
                        + buy.map { RecipeIngredient(name: $0, amount: "", haveIt: false) }
        } else {
            ingredients = []
        }
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
