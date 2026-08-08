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
            ingredients: [
                RecipeIngredient(name: "eggs", amount: "6", haveIt: true),
                RecipeIngredient(name: "spinach", amount: "2 cups", haveIt: true),
                RecipeIngredient(name: "cheddar", amount: "½ cup, grated", haveIt: true),
                RecipeIngredient(name: "onion", amount: "1 small, diced", haveIt: true),
                RecipeIngredient(name: "milk", amount: "¼ cup", haveIt: false),
            ],
            steps: [
                "Heat the oven to 375°F (190°C).",
                "In an oven-safe skillet, soften the onion in a little olive oil over medium heat, 3–4 min, then add the spinach and cook until wilted.",
                "Whisk the eggs with the milk, a pinch of salt and pepper.",
                "Pour over the veg, scatter the cheddar on top, and bake 18–20 min until the center is just set.",
            ],
            tips: [
                "No milk? A splash of water or cream works too.",
                "Leftovers keep 3 days — great cold in a lunchbox.",
            ],
            servings: 4,
            prepMinutes: 10,
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
            ingredients: [
                RecipeIngredient(name: "pasta", amount: "8 oz", haveIt: true),
                RecipeIngredient(name: "canned tomatoes", amount: "1 can (14 oz)", haveIt: true),
                RecipeIngredient(name: "garlic", amount: "3 cloves, minced", haveIt: true),
                RecipeIngredient(name: "onion", amount: "1 small, diced", haveIt: true),
                RecipeIngredient(name: "olive oil", amount: "2 tbsp", haveIt: true),
                RecipeIngredient(name: "fresh basil", amount: "a handful", haveIt: false),
            ],
            steps: [
                "Bring a large pot of well-salted water to a boil and cook the pasta to package time.",
                "Meanwhile, warm the olive oil over medium heat and gently fry the garlic and onion until soft and fragrant, ~5 min.",
                "Add the canned tomatoes, break them up, and simmer 12 min; season with salt and pepper.",
                "Toss the drained pasta through the sauce and finish with torn basil.",
            ],
            tips: [
                "A pinch of sugar rounds out acidic tomatoes.",
                "No fresh basil? A little dried oregano stirred into the sauce works.",
            ],
            servings: 2,
            prepMinutes: 5,
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
            ingredients: [
                RecipeIngredient(name: "eggs", amount: "3", haveIt: true),
                RecipeIngredient(name: "spinach", amount: "1 cup", haveIt: true),
                RecipeIngredient(name: "cheddar", amount: "¼ cup, grated", haveIt: true),
                RecipeIngredient(name: "tortillas", amount: "2 large", haveIt: false),
            ],
            steps: [
                "Whisk the eggs and scramble softly in a nonstick pan over medium-low heat.",
                "Fold in the spinach until wilted, then the grated cheddar until melty.",
                "Pile onto the tortillas, roll up, and toast seam-side down in the dry pan until golden.",
            ],
            tips: [
                "Add a dab of hot sauce or salsa for a lift.",
                "Wrap in foil to take it to go.",
            ],
            servings: 2,
            prepMinutes: 3,
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
        // The canned samples are conventional dishes; hold them to the same
        // dietary/allergen backstop as real suggestions so an allergic or
        // vegan user never sees a violating recipe presented as a match.
        return profile.compliantRecipes(from: recipes)
            .map { recipe -> Recipe in
                var r = recipe
                // Re-flag which ingredients the user actually has, based on their pantry.
                r.ingredients = recipe.ingredients.map { ing in
                    var copy = ing
                    copy.haveIt = onHand.contains(ing.name.lowercased())
                    return copy
                }
                // If nothing matched, surface a few real pantry items as "have".
                if r.usesOnHand.isEmpty {
                    r.ingredients.append(contentsOf: ingredients.prefix(3).map {
                        RecipeIngredient(name: $0.name, amount: "", haveIt: true)
                    })
                }
                return r
            }
            .prefix(count)
            .map { $0 }
    }

    static var profile: TasteProfile { TasteProfile.starter }
}
