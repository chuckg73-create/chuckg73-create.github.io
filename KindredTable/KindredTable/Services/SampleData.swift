import Foundation

/// On-device fallback content. Used when no Gemini API key is configured and to
/// power SwiftUI previews, so the whole app is explorable offline.
enum SampleData {

    static let ingredients: [Ingredient] = [
        Ingredient(name: "Eggs", category: .protein, quantity: "6", confidence: 0.82),
        Ingredient(name: "Spinach", category: .produce, confidence: 0.71),
        Ingredient(name: "Cheddar", category: .dairy, confidence: 0.64),
        Ingredient(name: "Onion", category: .produce, quantity: "2", confidence: 0.58),
        Ingredient(name: "Garlic", category: .produce, confidence: 0.51),
        Ingredient(name: "Pasta", category: .grain, quantity: "1 box"),
        Ingredient(name: "Canned tomatoes", category: .pantry, quantity: "2 cans"),
        Ingredient(name: "Olive oil", category: .condiment),
    ]

    static let recipes: [Recipe] = [
        Recipe(
            title: "Spinach & Cheddar Frittata",
            summary: "A fluffy baked egg dish that clears out the fridge in one pan.",
            mealType: .breakfast,
            usesOnHand: ["Eggs", "Spinach", "Cheddar", "Onion"],
            needsToBuy: ["Milk"],
            steps: [
                "Heat oven to 190°C (375°F).",
                "Soften the onion in olive oil, then wilt the spinach.",
                "Whisk 6 eggs with a splash of milk, salt and pepper.",
                "Pour over the veg, scatter cheddar, and bake 18–20 min until set.",
            ],
            cookMinutes: 25,
            difficulty: .easy,
            tags: ["vegetarian", "high-protein", "one-pan"],
            matchScore: 92,
            whyYoullLikeIt: "Comforting, quick, and leans on the eggs and greens you already have."
        ),
        Recipe(
            title: "Garlic Tomato Pasta",
            summary: "A weeknight red-sauce pasta built from pantry staples.",
            mealType: .dinner,
            usesOnHand: ["Pasta", "Canned tomatoes", "Garlic", "Onion", "Olive oil"],
            needsToBuy: ["Basil"],
            steps: [
                "Boil pasta in well-salted water.",
                "Gently fry garlic and onion in olive oil.",
                "Add canned tomatoes, simmer 12 minutes, season.",
                "Toss with the drained pasta and finish with basil.",
            ],
            cookMinutes: 20,
            difficulty: .easy,
            tags: ["vegetarian", "Italian", "budget"],
            matchScore: 88,
            whyYoullLikeIt: "Simple Italian comfort food that matches your love of Mediterranean flavours."
        ),
        Recipe(
            title: "Cheesy Egg & Greens Wrap",
            summary: "A five-minute handheld lunch using what's on the shelf.",
            mealType: .lunch,
            usesOnHand: ["Eggs", "Spinach", "Cheddar"],
            needsToBuy: ["Tortillas"],
            steps: [
                "Scramble the eggs softly.",
                "Fold in wilted spinach and grated cheddar.",
                "Wrap in a warm tortilla and toast until golden.",
            ],
            cookMinutes: 10,
            difficulty: .easy,
            tags: ["quick", "high-protein"],
            matchScore: 80,
            whyYoullLikeIt: "Fast and filling for a busy day, with no shopping trip required."
        ),
    ]

    /// Build lightly-tailored sample recipes referencing the real pantry so the
    /// offline experience still feels connected to what the user has.
    static func sampleRecipes(for ingredients: [Ingredient], profile: TasteProfile, count: Int) -> [Recipe] {
        let onHand = Set(ingredients.map { $0.name.lowercased() })
        return recipes
            .map { recipe -> Recipe in
                var r = recipe
                r.usesOnHand = recipe.usesOnHand.filter { onHand.contains($0.lowercased()) }
                if r.usesOnHand.isEmpty {
                    r.usesOnHand = Array(ingredients.prefix(3).map { $0.name })
                }
                return r
            }
            .prefix(count)
            .map { $0 }
    }

    static var profile: TasteProfile { TasteProfile.starter }
}
