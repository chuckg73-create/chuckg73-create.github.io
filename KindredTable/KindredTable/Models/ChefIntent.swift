import Foundation

/// The structured meaning of a natural-language request to the app's chef agent.
/// The agent PARSES the cook's words into this, then ROUTES over the existing
/// recipe engines — it never invents recipes itself.
struct ChefIntent: Codable, Hashable {
    enum Action: String, Codable {
        case findMeals      // "something to cook", "ideas for dinner"
        case specificDish   // "make me carbonara"
        case planWeek       // "plan my week", "3 dinners for the week"
        case unknown        // couldn't tell — ask for a nudge
    }

    var action: Action
    var dish: String?           // for specificDish
    var include: [String]       // ingredients they want in it
    var avoid: [String]         // things to avoid THIS time (on top of permanent dislikes)
    var cuisine: String?        // e.g. "Thai"
    var maxMinutes: Int?        // time limit if they asked for "quick"/"30 min"
    var servings: Int?          // if they named a headcount
    var days: Int?              // for planWeek
    var mealType: String?       // breakfast|lunch|dinner|snack|dessert
    var reply: String           // a warm one-sentence acknowledgement to show the cook

    init(action: Action, dish: String? = nil, include: [String] = [], avoid: [String] = [],
         cuisine: String? = nil, maxMinutes: Int? = nil, servings: Int? = nil, days: Int? = nil,
         mealType: String? = nil, reply: String = "") {
        self.action = action; self.dish = dish; self.include = include; self.avoid = avoid
        self.cuisine = cuisine; self.maxMinutes = maxMinutes; self.servings = servings
        self.days = days; self.mealType = mealType; self.reply = reply
    }

    /// Tolerant decoding — the model may omit fields or send nulls.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        action = ((try? c.decodeIfPresent(Action.self, forKey: .action)) ?? nil) ?? .findMeals
        dish = (try? c.decodeIfPresent(String.self, forKey: .dish)) ?? nil
        include = ((try? c.decodeIfPresent([String].self, forKey: .include)) ?? nil) ?? []
        avoid = ((try? c.decodeIfPresent([String].self, forKey: .avoid)) ?? nil) ?? []
        cuisine = (try? c.decodeIfPresent(String.self, forKey: .cuisine)) ?? nil
        maxMinutes = (try? c.decodeIfPresent(Int.self, forKey: .maxMinutes)) ?? nil
        servings = (try? c.decodeIfPresent(Int.self, forKey: .servings)) ?? nil
        days = (try? c.decodeIfPresent(Int.self, forKey: .days)) ?? nil
        mealType = (try? c.decodeIfPresent(String.self, forKey: .mealType)) ?? nil
        reply = ((try? c.decodeIfPresent(String.self, forKey: .reply)) ?? nil) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case action, dish, include, avoid, cuisine, maxMinutes, servings, days, mealType, reply
    }

    /// Constraints folded into a prompt block for the existing engines, or nil.
    var constraintBlock: String? {
        var parts: [String] = []
        if !include.isEmpty { parts.append("must use: \(include.joined(separator: ", "))") }
        if !avoid.isEmpty { parts.append("avoid this time: \(avoid.joined(separator: ", "))") }
        if let cuisine, !cuisine.isEmpty { parts.append("cuisine: \(cuisine)") }
        if let maxMinutes, maxMinutes > 0 { parts.append("ready in about \(maxMinutes) minutes or less") }
        if let mealType, !mealType.isEmpty { parts.append("meal: \(mealType)") }
        guard !parts.isEmpty else { return nil }
        return "REQUEST CONSTRAINTS — the cook asked for: \(parts.joined(separator: "; ")). Honor these on top of their taste profile and hard dietary rules."
    }
}
