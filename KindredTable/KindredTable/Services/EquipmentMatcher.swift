import Foundation

/// Decides whether two pieces of kitchen equipment are "the same thing" for
/// de-duplication — so a scanned "Smoker" doesn't pile up next to a typed
/// "Traeger", or "Pressure cooker" next to "Instant Pot".
///
/// Matching is by a canonical key: lower-cased, punctuation-normalised, then run
/// through a brand/synonym table. It's used for COMPARISON only — the label the
/// cook sees is never changed.
enum EquipmentMatcher {

    /// True if `a` and `b` refer to the same appliance.
    static func sameAppliance(_ a: String, _ b: String) -> Bool {
        canonical(a) == canonical(b)
    }

    /// True if `name` already appears in `list` (brand/synonym-aware).
    static func contains(_ list: [String], _ name: String) -> Bool {
        let key = canonical(name)
        return list.contains { canonical($0) == key }
    }

    /// The canonical dedup key for a piece of equipment.
    static func canonical(_ raw: String) -> String {
        var s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Treat hyphens/underscores as spaces and collapse runs of whitespace,
        // so "air-fryer" == "air fryer" and "rice  cooker" == "rice cooker".
        s = s.replacingOccurrences(of: "-", with: " ")
        s = s.replacingOccurrences(of: "_", with: " ")
        s = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        // Drop a trailing brand-style "machine"/"cooker" only via the table below;
        // otherwise map known brands & synonyms to one generic name.
        return synonyms[s] ?? s
    }

    /// Brand / synonym → generic canonical name. Keys are already normalised
    /// (lower-case, single-spaced, no hyphens). Only high-confidence pairs — we'd
    /// rather miss a merge than wrongly collapse two different tools.
    private static let synonyms: [String: String] = [
        // Smoker / pellet grill
        "traeger": "smoker",
        "pit boss": "smoker",
        "pellet smoker": "smoker",
        "pellet grill": "smoker",
        "smoker grill": "smoker",
        // Pressure cooker / multi-cooker
        "instant pot": "pressure cooker",
        "instapot": "pressure cooker",
        "insta pot": "pressure cooker",
        "multi cooker": "pressure cooker",
        // Slow cooker
        "crockpot": "slow cooker",
        "crock pot": "slow cooker",
        // Blender
        "vitamix": "blender",
        "nutribullet": "blender",
        "magic bullet": "blender",
        "ninja blender": "blender",
        // Stand mixer
        "kitchenaid": "stand mixer",
        "kitchen aid": "stand mixer",
        "kitchenaid mixer": "stand mixer",
        // Air fryer
        "airfryer": "air fryer",
        "instant vortex": "air fryer",
        // Sous vide
        "anova": "sous vide",
        "joule": "sous vide",
        "sous vide machine": "sous vide",
        "sous vide cooker": "sous vide",
        "immersion circulator": "sous vide",
        // Dutch oven
        "le creuset": "dutch oven",
        // Cast iron
        "cast iron skillet": "cast iron",
        "cast iron pan": "cast iron",
        "cast iron pot": "cast iron",
        "cast iron": "cast iron",
        // Griddle
        "blackstone": "griddle",
        "flat top": "griddle",
        // Microwave
        "microwave oven": "microwave",
        // Espresso
        "nespresso": "espresso machine",
        "espresso maker": "espresso machine",
        // Rice cooker
        "rice maker": "rice cooker",
    ]
}
