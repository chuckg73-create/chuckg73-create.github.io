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
        // Fall back to the longest (most specific) vocabulary key contained in a
        // token, so "green beans" matches "green bean" (produce) rather than the
        // shorter "beans" (dried legume / protein).
        var best: (key: String, value: Match)?
        for token in candidates {
            for (key, value) in table where token.contains(key) {
                if best == nil || key.count > best!.key.count {
                    best = (key, value)
                }
            }
        }
        return best?.value
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

    /// Best-guess grocery category for a free-text ingredient name — used to
    /// auto-file items the user types without picking a category.
    static func categorize(_ rawName: String) -> IngredientCategory {
        let name = rawName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .other }

        // 1. Curated vocabulary (handles most common foods, incl. substrings).
        if let hit = match(name) { return hit.category }

        // 2. Word-by-word against the vocabulary.
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        for word in words where table[word] != nil {
            return table[word]!.category
        }
        for word in words {
            for (key, value) in table where word == key || word.contains(key) {
                return value.category
            }
        }

        // 3. Broad keyword heuristics for the long tail of foods, ordered so
        //    more specific terms win.
        for (keyword, category) in heuristics where name.contains(keyword) {
            return category
        }
        return .other
    }

    /// Ordered keyword → category hints for foods outside the core vocabulary.
    private static let heuristics: [(String, IngredientCategory)] = [
        // Protein / deli / seafood
        ("salami", .protein), ("pepperoni", .protein), ("prosciutto", .protein),
        ("chorizo", .protein), ("bologna", .protein), ("pastrami", .protein),
        ("brisket", .protein), ("veal", .protein), ("venison", .protein),
        ("hot dog", .protein), ("hotdog", .protein), ("jerky", .protein),
        ("anchovy", .protein), ("sardine", .protein), ("scallop", .protein),
        ("clam", .protein), ("mussel", .protein), ("oyster", .protein),
        ("seitan", .protein), ("burger", .protein), ("patty", .protein),
        // Grains / bakery
        ("flour", .grain), ("bread", .grain), ("rice", .grain), ("pasta", .grain),
        ("noodle", .grain), ("oat", .grain), ("cereal", .grain), ("cracker", .grain),
        ("tortilla", .grain), ("bagel", .grain), ("bun", .grain),
        ("cornmeal", .grain), ("grits", .grain), ("granola", .grain),
        ("croissant", .grain), ("muffin", .grain), ("waffle", .grain),
        ("pancake", .grain), ("biscuit", .grain), ("crouton", .grain),
        // Dairy
        ("milk", .dairy), ("cheese", .dairy), ("yogurt", .dairy), ("yoghurt", .dairy),
        ("cream", .dairy), ("kefir", .dairy), ("custard", .dairy), ("ghee", .dairy),
        // Condiments
        ("sauce", .condiment), ("ketchup", .condiment), ("mustard", .condiment),
        ("mayo", .condiment), ("dressing", .condiment), ("vinegar", .condiment),
        ("syrup", .condiment), ("honey", .condiment), ("jam", .condiment),
        ("jelly", .condiment), ("salsa", .condiment), ("relish", .condiment),
        ("marinade", .condiment), ("nutella", .condiment),
        // Spices / seasoning
        ("salt", .spice), ("pepper", .spice), ("cumin", .spice), ("paprika", .spice),
        ("cinnamon", .spice), ("oregano", .spice), ("thyme", .spice),
        ("rosemary", .spice), ("curry", .spice), ("cayenne", .spice),
        ("nutmeg", .spice), ("turmeric", .spice), ("vanilla", .spice),
        ("seasoning", .spice), ("spice", .spice),
        // Frozen
        ("frozen", .frozen), ("ice cream", .frozen), ("popsicle", .frozen),
        // Pantry staples
        ("bean", .pantry), ("canned", .pantry), ("sugar", .pantry),
        ("broth", .pantry), ("stock", .pantry),
    ]

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
