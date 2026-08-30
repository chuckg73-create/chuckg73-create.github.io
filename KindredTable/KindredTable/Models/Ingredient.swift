import Foundation

/// A single pantry / fridge item the user has on hand.
struct Ingredient: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var category: IngredientCategory
    /// Optional free-text quantity, e.g. "2", "half a bag", "400g".
    var quantity: String?
    /// Vision confidence 0…1 when the item was auto-detected; nil when added by hand.
    var confidence: Double?
    var addedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: IngredientCategory = .other,
        quantity: String? = nil,
        confidence: Double? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.quantity = quantity
        self.confidence = confidence
        self.addedAt = addedAt
    }

    /// True when this ingredient was recognised on-device rather than typed.
    var isAutoDetected: Bool { confidence != nil }

    /// Freshness relative to when it was added, based on the category's shelf life.
    /// Shelf-stable items (spices, pantry, condiments) never age.
    func freshness(now: Date = Date()) -> FreshnessStatus {
        guard let shelf = category.shelfLifeDays else { return .stable }
        let daysOld = Int(now.timeIntervalSince(addedAt) / 86_400)
        let remaining = shelf - daysOld
        if remaining <= 0 { return .past(daysOver: -remaining) }
        if remaining <= 2 { return .useSoon(daysLeft: remaining) }
        return .fresh
    }
}

/// How close a perishable is to needing attention.
enum FreshnessStatus: Equatable {
    case stable                    // shelf-stable — never flagged
    case fresh
    case useSoon(daysLeft: Int)
    case past(daysOver: Int)

    /// Should the cook be nudged to confirm/use it?
    var needsAttention: Bool {
        switch self {
        case .useSoon, .past: return true
        case .stable, .fresh: return false
        }
    }

    /// Short badge label, or nil when nothing to show.
    var shortLabel: String? {
        switch self {
        case .stable, .fresh: return nil
        case .useSoon(let d): return d <= 0 ? "Use today" : "Use in \(d)d"
        case .past: return "Check freshness"
        }
    }
}

/// Broad grocery categories used for grouping and iconography.
enum IngredientCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case produce
    case protein
    case dairy
    case grain
    case condiment
    case spice
    case frozen
    case pantry
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .protein: return "Protein"
        case .dairy: return "Dairy"
        case .grain: return "Grains"
        case .condiment: return "Condiments"
        case .spice: return "Spices"
        case .frozen: return "Frozen"
        case .pantry: return "Pantry"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .produce: return "carrot.fill"
        case .protein: return "fish.fill"
        case .dairy: return "drop.fill"
        case .grain: return "leaf.fill"
        case .condiment: return "takeoutbag.and.cup.and.straw.fill"
        case .spice: return "flame.fill"
        case .frozen: return "snowflake"
        case .pantry: return "cabinet.fill"
        case .other: return "basket.fill"
        }
    }

    /// Rough shelf life once it's in the kitchen, in days; nil = shelf-stable
    /// (spices, pantry staples, condiments — they don't get freshness nudges).
    var shelfLifeDays: Int? {
        switch self {
        case .produce: return 5
        case .protein: return 3
        case .dairy: return 7
        case .frozen: return 90
        case .grain, .condiment, .spice, .pantry, .other: return nil
        }
    }

    /// Sort order for the grouped pantry list (most "fresh" first).
    var sortRank: Int {
        switch self {
        case .produce: return 0
        case .protein: return 1
        case .dairy: return 2
        case .grain: return 3
        case .frozen: return 4
        case .pantry: return 5
        case .condiment: return 6
        case .spice: return 7
        case .other: return 8
        }
    }
}
