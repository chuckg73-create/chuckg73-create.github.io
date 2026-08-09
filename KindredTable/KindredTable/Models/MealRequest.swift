import Foundation

/// What kind of dish the cook is after — used to steer a recipe request.
enum Course: String, CaseIterable, Identifiable, Hashable {
    case any, main, side, soup, salad, dessert, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: return "Any"
        case .main: return "Main"
        case .side: return "Side"
        case .soup: return "Soup"
        case .salad: return "Salad"
        case .dessert: return "Dessert"
        case .snack: return "Snack"
        }
    }

    /// How the course reads inside the recipe prompt (nil for "any").
    var promptPhrase: String? {
        switch self {
        case .any: return nil
        case .main: return "a main dish"
        case .side: return "a side dish"
        case .soup: return "a soup"
        case .salad: return "a salad"
        case .dessert: return "a dessert"
        case .snack: return "a snack"
        }
    }

    var systemImage: String {
        switch self {
        case .any: return "square.grid.2x2"
        case .main: return "fork.knife"
        case .side: return "leaf.fill"
        case .soup: return "cup.and.saucer.fill"
        case .salad: return "carrot.fill"
        case .dessert: return "birthday.cake.fill"
        case .snack: return "popcorn.fill"
        }
    }
}

/// A flexible recipe request: an optional dish, ingredients to build around, a
/// course, equipment to use, and whether to lean on what's on hand.
struct MealRequest {
    var dish: String = ""
    var includeIngredients: [String] = []
    var course: Course = .any
    var equipment: [String] = []
    var preferOnHand: Bool = true

    /// True when the cook hasn't specified anything to act on.
    var isEmpty: Bool {
        dish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && includeIngredients.isEmpty
            && course == .any
            && equipment.isEmpty
    }

    /// Common appliances offered as quick picks, merged with the cook's own.
    static let commonEquipment = ["Oven", "Stovetop", "Air fryer", "Slow cooker", "Instant Pot", "Grill", "Blender", "Microwave"]
}
