import Foundation

/// A whole cookbook exported to a single file so it can be handed to family —
/// AirDrop, Messages, Mail, Save to Files — and imported back as real,
/// editable recipes rather than a one-way text dump. Flat JSON (not a
/// document bundle) so it always travels as one ordinary attachment.
struct CookbookPackage: Codable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var exportedAt: Date
    /// Free text the exporter enters — "Mom's Recipes", "Sarah's Cookbook".
    var cookbookName: String
    var recipes: [Recipe]
    /// The cook's own photo for each recipe, keyed by `recipe.id.uuidString`.
    /// Not every recipe has one.
    var photos: [String: Data]

    init(cookbookName: String, recipes: [Recipe], photos: [String: Data]) {
        self.formatVersion = Self.currentFormatVersion
        self.exportedAt = Date()
        self.cookbookName = cookbookName
        self.recipes = recipes
        self.photos = photos
    }
}
