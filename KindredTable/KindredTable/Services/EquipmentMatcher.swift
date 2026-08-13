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

    /// Brand / synonym → generic canonical name.
    ///
    /// DELIBERATELY CONSERVATIVE. We only collapse two names when they're the
    /// SAME TOOL with the same cooking capability — a genericized trademark
    /// (Crock-Pot = slow cooker) or a wording variant (air-fryer = air fryer).
    /// We do NOT flatten a brand that unlocks capabilities the generic lacks:
    /// a Vitamix (hot soup, nut butter, milling) is not a "blender", a KitchenAid
    /// with attachments is not just a "stand mixer" — those stay their own entry
    /// so recipe steps can use what they can really do. When in doubt, keep them
    /// distinct: a missed merge is a harmless extra chip; a wrong merge hides a
    /// capability. Keys are already normalised (lower-case, single-spaced, no hyphens).
    private static let synonyms: [String: String] = [
        // Slow cooker — "Crock-Pot" is the genericized trademark.
        "crockpot": "slow cooker",
        "crock pot": "slow cooker",
        // Pressure cooker — pressure cooking is the defining function.
        "instant pot": "pressure cooker",
        "instapot": "pressure cooker",
        "insta pot": "pressure cooker",
        "multi cooker": "pressure cooker",
        // Smoker — pellet smokers/grills; "smoker" keeps the smoking capability
        // (unlike collapsing to a plain "grill").
        "traeger": "smoker",
        "pit boss": "smoker",
        "pellet smoker": "smoker",
        "pellet grill": "smoker",
        "smoker grill": "smoker",
        // Air fryer — wording / single-purpose brand.
        "airfryer": "air fryer",
        "instant vortex": "air fryer",
        // Sous vide — single-purpose immersion circulators, no capability delta.
        "anova": "sous vide",
        "joule": "sous vide",
        "sous vide machine": "sous vide",
        "sous vide cooker": "sous vide",
        "immersion circulator": "sous vide",
        // Pure wording variants.
        "microwave oven": "microwave",
        "flat top": "griddle",
        "espresso maker": "espresso machine",
        "rice maker": "rice cooker",
        // NOTE: intentionally NOT merged — capability-bearing, keep distinct:
        // Vitamix / Blendtec (≠ blender), KitchenAid (≠ stand mixer),
        // Le Creuset (≠ generic dutch oven), Ninja/NutriBullet (own quirks).
    ]
}
