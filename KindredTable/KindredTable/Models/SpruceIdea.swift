import Foundation

/// A quick "chef's touch" to elevate a dish — a garnish, a finishing flavor, a
/// plating tip, or an easy level-up.
struct SpruceIdea: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: String        // Garnish | Flavor | Plating | Level up
    var text: String

    var systemImage: String {
        let k = kind.lowercased()
        if k.contains("garnish") { return "leaf.fill" }
        if k.contains("flavor") || k.contains("flavour") || k.contains("season") { return "flame.fill" }
        if k.contains("plat") || k.contains("serve") { return "fork.knife.circle.fill" }
        return "arrow.up.circle.fill"
    }
}
