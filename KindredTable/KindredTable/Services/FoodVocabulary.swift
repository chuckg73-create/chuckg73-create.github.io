import Foundation

/// Maps raw Vision classifier identifiers to canonical ingredient names and
/// grocery categories. Vision's taxonomy is broad (it also returns non-food
/// labels), so this acts as both a filter and a normaliser.
enum FoodVocabulary {

    struct Match {
        let name: String
        let category: IngredientCategory
    }

    /// Attempt to map a Vision identifier (which may be lowercase and may contain
    /// multiple comma/underscore separated synonyms) to a known food.
    static func match(_ identifier: String) -> Match? {
        let candidates = identifier
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0 == "," || $0 == "/" })
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for token in candidates {
            if let hit = table[token] {
                return hit
            }
        }
        // Fall back to substring hits for compound labels like "green bell pepper".
        for token in candidates {
            for (key, value) in table where token.contains(key) {
                return value
            }
        }
        return nil
    }

    private static func m(_ name: String, _ category: IngredientCategory) -> Match {
        Match(name: name, category: category)
    }

    /// Every known food, de-duplicated by display name and sorted — used to
    /// power type-ahead suggestions in the ingredient editor.
    static let allFoods: [Match] = {
        var seen = Set<String>()
        var result: [Match] = []
        for match in table.values where seen.insert(match.name.lowercased()).inserted {
            result.append(match)
        }
        return result.sorted { $0.name < $1.name }
    }()

    /// Type-ahead suggestions for a partially typed ingredient name. Prefix
    /// matches rank above substring matches; exact matches are omitted so a
    /// chosen suggestion disappears from the list.
    static func suggestions(for query: String, limit: Int = 6) -> [Match] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        let matches = allFoods.filter { $0.name.lowercased() != q && $0.name.lowercased().contains(q) }
        return Array(
            matches.sorted { a, b in
                let ap = a.name.lowercased().hasPrefix(q)
                let bp = b.name.lowercased().hasPrefix(q)
                if ap != bp { return ap }
                return a.name < b.name
            }
            .prefix(limit)
        )
    }

    /// Curated food vocabulary. Not exhaustive — the editable ingredient list
    /// lets the user correct or add anything the classifier misses.
    static let table: [String: Match] = {
        var t: [String: Match] = [:]

        // Produce
        let produce = [
            "apple", "banana", "orange", "lemon", "lime", "strawberry", "blueberry",
            "raspberry", "grape", "avocado", "tomato", "potato", "sweet potato",
            "onion", "garlic", "carrot", "broccoli", "cauliflower", "spinach",
            "lettuce", "kale", "cabbage", "cucumber", "zucchini", "eggplant",
            "bell pepper", "pepper", "chili", "mushroom", "corn", "peas", "green bean",
            "celery", "asparagus", "ginger", "scallion", "leek", "beet", "radish",
            "pumpkin", "squash", "pineapple", "mango", "peach", "pear", "cherry",
            "watermelon", "cantaloupe", "kiwi", "pomegranate", "cranberry", "fig",
            "date", "coconut", "olive", "artichoke", "brussels sprout", "turnip",
            "parsnip", "shallot", "cilantro", "parsley", "basil", "mint", "herb",
        ]
        for p in produce { t[p] = m(p.capitalizedFirst, .produce) }

        // Protein
        let protein = [
            "chicken", "beef", "pork", "lamb", "turkey", "bacon", "sausage", "ham",
            "steak", "ground beef", "fish", "salmon", "tuna", "shrimp", "prawn",
            "crab", "lobster", "cod", "tilapia", "tofu", "tempeh", "egg", "eggs",
            "beans", "black bean", "chickpea", "lentil", "kidney bean", "edamame",
            "meatball", "ribs", "duck",
        ]
        for p in protein { t[p] = m(p.capitalizedFirst, .protein) }

        // Dairy
        let dairy = [
            "milk", "cheese", "cheddar", "mozzarella", "parmesan", "feta", "butter",
            "yogurt", "yoghurt", "cream", "sour cream", "cream cheese", "ricotta",
            "brie", "goat cheese",
        ]
        for d in dairy { t[d] = m(d.capitalizedFirst, .dairy) }

        // Grains
        let grain = [
            "rice", "pasta", "spaghetti", "noodle", "noodles", "bread", "baguette",
            "tortilla", "flour", "oats", "oatmeal", "quinoa", "couscous", "cereal",
            "bagel", "cracker", "bun", "pita", "barley", "cornmeal", "polenta",
        ]
        for g in grain { t[g] = m(g.capitalizedFirst, .grain) }

        // Condiments
        let condiment = [
            "ketchup", "mustard", "mayonnaise", "mayo", "soy sauce", "hot sauce",
            "sriracha", "bbq sauce", "salsa", "pesto", "hummus", "honey", "syrup",
            "jam", "jelly", "peanut butter", "vinegar", "olive oil", "oil",
            "salad dressing", "tahini", "miso", "fish sauce",
        ]
        for c in condiment { t[c] = m(c.capitalizedFirst, .condiment) }

        // Spices
        let spice = [
            "salt", "black pepper", "cumin", "paprika", "cinnamon", "turmeric",
            "oregano", "thyme", "rosemary", "chili powder", "curry powder",
            "cayenne", "nutmeg", "ginger powder", "garlic powder", "bay leaf",
            "vanilla", "coriander seed",
        ]
        for s in spice { t[s] = m(s.capitalizedFirst, .spice) }

        // Frozen / pantry misc
        t["ice cream"] = m("Ice cream", .frozen)
        t["frozen pizza"] = m("Frozen pizza", .frozen)
        t["pizza"] = m("Pizza", .frozen)
        t["dumpling"] = m("Dumplings", .frozen)

        t["canned tomato"] = m("Canned tomatoes", .pantry)
        t["tomato sauce"] = m("Tomato sauce", .pantry)
        t["stock"] = m("Stock", .pantry)
        t["broth"] = m("Broth", .pantry)
        t["coconut milk"] = m("Coconut milk", .pantry)
        t["sugar"] = m("Sugar", .pantry)
        t["nut"] = m("Nuts", .pantry)
        t["almond"] = m("Almonds", .pantry)
        t["walnut"] = m("Walnuts", .pantry)
        t["cashew"] = m("Cashews", .pantry)
        t["raisin"] = m("Raisins", .pantry)
        t["chocolate"] = m("Chocolate", .pantry)

        return t
    }()
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
