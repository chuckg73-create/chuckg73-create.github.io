import Foundation

/// A suggested swap for one recipe ingredient — name, an amount for this recipe,
/// and a short reason it works.
struct SubstitutionOption: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var amount: String
    var note: String

    /// "1 can, drained black beans" — or just the name when no amount.
    var display: String {
        amount.trimmingCharacters(in: .whitespaces).isEmpty ? name : "\(amount) \(name)"
    }
}

/// Lets a recipe ingredient drive a `.sheet(item:)` (swap flow). Computed id, so
/// it doesn't affect Codable/Hashable behavior anywhere else.
extension RecipeIngredient: Identifiable {
    public var id: String { "\(name)|\(amount)" }
}
