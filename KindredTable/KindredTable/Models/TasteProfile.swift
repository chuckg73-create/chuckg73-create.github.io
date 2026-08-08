import Foundation

/// The user's personal taste "DNA" — the same idea as KindredCompass's DNA
/// profile, focused on cooking. Stored locally and sent (without any personal
/// identifiers) to the recipe-matching model.
struct TasteProfile: Codable, Hashable {
    var diets: Set<Diet>
    var lovedCuisines: [String]
    var dislikedIngredients: [String]
    var allergens: [String]
    var spiceLevel: SpiceLevel
    var skill: CookingSkill
    /// Cap on suggested cook time, in minutes.
    var maxCookMinutes: Int
    /// Cooking equipment the user owns, e.g. "Air fryer", "Traeger". Recipes are
    /// steered toward methods this gear enables.
    var equipment: [String]
    /// Free-text extra notes, e.g. "cooking for a toddler too".
    var notes: String

    init(
        diets: Set<Diet> = [],
        lovedCuisines: [String] = [],
        dislikedIngredients: [String] = [],
        allergens: [String] = [],
        spiceLevel: SpiceLevel = .medium,
        skill: CookingSkill = .comfortable,
        maxCookMinutes: Int = 45,
        equipment: [String] = [],
        notes: String = ""
    ) {
        self.diets = diets
        self.lovedCuisines = lovedCuisines
        self.dislikedIngredients = dislikedIngredients
        self.allergens = allergens
        self.spiceLevel = spiceLevel
        self.skill = skill
        self.maxCookMinutes = maxCookMinutes
        self.equipment = equipment
        self.notes = notes
    }

    /// Tolerant decoding so profiles saved by older versions (without newer
    /// fields like `equipment`) still load instead of resetting to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        diets = try c.decodeIfPresent(Set<Diet>.self, forKey: .diets) ?? []
        lovedCuisines = try c.decodeIfPresent([String].self, forKey: .lovedCuisines) ?? []
        dislikedIngredients = try c.decodeIfPresent([String].self, forKey: .dislikedIngredients) ?? []
        allergens = try c.decodeIfPresent([String].self, forKey: .allergens) ?? []
        spiceLevel = try c.decodeIfPresent(SpiceLevel.self, forKey: .spiceLevel) ?? .medium
        skill = try c.decodeIfPresent(CookingSkill.self, forKey: .skill) ?? .comfortable
        maxCookMinutes = try c.decodeIfPresent(Int.self, forKey: .maxCookMinutes) ?? 45
        equipment = try c.decodeIfPresent([String].self, forKey: .equipment) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case diets, lovedCuisines, dislikedIngredients, allergens
        case spiceLevel, skill, maxCookMinutes, equipment, notes
    }

    /// Common appliances offered as quick-add chips in the profile editor.
    static let commonEquipment = [
        "Oven", "Gas stove", "Microwave", "Air fryer", "Slow cooker",
        "Instant Pot", "Sous vide", "Grill", "Pellet smoker", "Griddle",
        "Blender", "Food processor", "Toaster", "Rice cooker", "Panini press",
        "Espresso machine", "Stand mixer",
    ]

    static let empty = TasteProfile()

    /// A friendly starter profile used on first launch.
    static let starter = TasteProfile(
        lovedCuisines: ["Italian", "Mediterranean", "Thai"],
        spiceLevel: .medium,
        skill: .comfortable,
        maxCookMinutes: 40,
        notes: ""
    )
}

enum Diet: String, Codable, CaseIterable, Identifiable, Hashable {
    case vegetarian, vegan, pescatarian, glutenFree, dairyFree, keto, halal, kosher, lowCarb, highProtein

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .glutenFree: return "Gluten-free"
        case .dairyFree: return "Dairy-free"
        case .keto: return "Keto"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        case .lowCarb: return "Low-carb"
        case .highProtein: return "High-protein"
        }
    }

    /// An explicit, non-negotiable instruction for the recipe model.
    var hardRule: String {
        switch self {
        case .vegetarian:  return "VEGETARIAN: no meat, poultry, or fish/seafood (dairy and eggs are fine)."
        case .vegan:       return "VEGAN: no animal products whatsoever — no meat, poultry, fish/seafood, dairy, eggs, honey, gelatin, or animal-based stock/broth."
        case .pescatarian: return "PESCATARIAN: no meat or poultry; fish and seafood are allowed."
        case .glutenFree:  return "GLUTEN-FREE: no wheat, barley, rye, or regular soy sauce; use certified gluten-free substitutes."
        case .dairyFree:   return "DAIRY-FREE: no milk, butter, cheese, cream, yogurt, or whey; use plant-based substitutes."
        case .keto:        return "KETO: very low carb — no sugar, grains, bread, pasta, rice, potatoes, or high-sugar fruit; keep net carbs low."
        case .halal:       return "HALAL: no pork or pork-derived ingredients and no alcohol; any meat must be halal."
        case .kosher:      return "KOSHER: no pork or shellfish, and never combine meat with dairy in the same dish."
        case .lowCarb:     return "LOW-CARB: minimize sugar, grains, and starchy ingredients."
        case .highProtein: return "HIGH-PROTEIN: make protein the centerpiece of every dish."
        }
    }
}

// MARK: - Dietary compliance backstop

/// Client-side safety net behind the prompt's HARD DIETARY RULES: the model is
/// *asked* to comply, but a slip-up must never reach the screen. Matching is
/// deliberately conservative (whole words, common synonym groups) — it can't
/// judge macro-based diets like keto, which stay prompt-only.
extension Diet {
    /// Ingredient words this diet can never contain. Empty for macro-based
    /// diets that aren't checkable from an ingredient list.
    var forbiddenIngredientTerms: [String] {
        switch self {
        case .vegetarian:  return Self.meatTerms + Self.seafoodTerms
        case .vegan:       return Self.meatTerms + Self.seafoodTerms + Self.dairyTerms
                                + ["egg", "honey", "gelatin"]
        case .pescatarian: return Self.meatTerms
        case .glutenFree:  return Self.glutenTerms
        case .dairyFree:   return Self.dairyTerms
        case .halal:       return Self.porkTerms + ["wine", "beer", "alcohol", "rum", "brandy", "sake", "mirin"]
        case .kosher:      return Self.porkTerms + Self.shellfishTerms
        case .keto, .lowCarb, .highProtein: return []
        }
    }

    private static let porkTerms = ["pork", "bacon", "ham", "prosciutto", "pancetta", "lard", "chorizo", "pepperoni", "salami"]
    private static let meatTerms = porkTerms
        + ["beef", "steak", "chicken", "turkey", "lamb", "veal", "duck", "sausage", "meatball", "brisket"]
    private static let shellfishTerms = ["shrimp", "prawn", "crab", "lobster", "clam", "mussel", "oyster", "scallop"]
    private static let seafoodTerms = shellfishTerms
        + ["fish", "salmon", "tuna", "cod", "tilapia", "anchovy", "sardine", "halibut", "trout"]
    private static let dairyTerms = ["milk", "butter", "cheese", "cream", "yogurt", "whey", "ghee", "cheddar", "parmesan", "mozzarella", "feta", "ricotta"]
    private static let glutenTerms = ["wheat", "flour", "pasta", "bread", "barley", "rye", "couscous", "breadcrumb", "tortilla", "noodle", "cracker"]
}

extension TasteProfile {
    /// Common allergen group names users type, expanded to concrete ingredient
    /// words. Unrecognised allergens are matched literally.
    private static let allergenGroups: [String: [String]] = [
        "dairy": ["milk", "butter", "cheese", "cream", "yogurt", "whey", "ghee", "cheddar", "parmesan", "mozzarella", "feta", "ricotta"],
        "gluten": ["wheat", "flour", "pasta", "bread", "barley", "rye", "couscous", "breadcrumb", "tortilla", "noodle", "cracker"],
        "nuts": ["almond", "walnut", "cashew", "pecan", "pistachio", "hazelnut", "macadamia", "nut"],
        "tree nuts": ["almond", "walnut", "cashew", "pecan", "pistachio", "hazelnut", "macadamia"],
        "shellfish": ["shrimp", "prawn", "crab", "lobster", "clam", "mussel", "oyster", "scallop"],
        "soy": ["soy", "tofu", "edamame", "tempeh"],
        "fish": ["fish", "salmon", "tuna", "cod", "tilapia", "anchovy", "sardine", "halibut", "trout"],
        "sesame": ["sesame", "tahini"],
    ]

    /// Ingredient names in `recipe` that violate this profile's allergens or
    /// exclusion diets. Empty means the recipe passes the backstop check.
    func violatingIngredients(in recipe: Recipe) -> [String] {
        var terms: [String] = []
        for allergen in allergens {
            let key = allergen.lowercased().trimmingCharacters(in: .whitespaces)
            terms.append(contentsOf: Self.allergenGroups[key] ?? [key])
        }
        for diet in diets {
            terms.append(contentsOf: diet.forbiddenIngredientTerms)
        }
        guard !terms.isEmpty else { return [] }

        return recipe.ingredients
            .map(\.name)
            .filter { name in terms.contains { Self.containsWord($0, in: name) } }
    }

    /// Drops recipes that fail the backstop check.
    func compliantRecipes(from recipes: [Recipe]) -> [Recipe] {
        recipes.filter { violatingIngredients(in: $0).isEmpty }
    }

    /// Whole-word, plural-tolerant match, so "egg" flags "eggs benedict" but
    /// not "eggplant".
    private static func containsWord(_ term: String, in text: String) -> Bool {
        var base = term.lowercased()
        if base.hasSuffix("es") { base = String(base.dropLast(2)) }
        else if base.hasSuffix("s") { base = String(base.dropLast()) }
        guard !base.isEmpty else { return false }
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: base))(es|s)?\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

enum SpiceLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case mild, medium, hot, fiery

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CookingSkill: String, Codable, CaseIterable, Identifiable, Hashable {
    case beginner, comfortable, confident

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
