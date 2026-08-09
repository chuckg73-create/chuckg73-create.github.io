import Foundation

/// Scales a recipe's ingredient amounts up or down by portion count, entirely
/// on-device — so a recipe written for 4 (Mom's card, an app find) can be cooked
/// for 1, 2, 6… instantly, with no network call.
///
/// It parses the leading quantity out of an amount string ("2 cups", "1 1/2 lb",
/// "½ tsp", "3-4 cloves"), multiplies by the scale factor, and re-renders it as a
/// friendly fraction. Non-numeric amounts ("to taste", "a pinch", "1 can") are
/// left untouched — halving "to taste" would be nonsense.
enum RecipeScaler {

    /// Return a copy of `recipe` scaled from its own `servings` to `target`.
    /// Amounts change; steps/tips are left as written (with a note in the UI).
    static func scaled(_ recipe: Recipe, to target: Int) -> Recipe {
        let base = max(1, recipe.servings)
        let want = max(1, target)
        guard base != want else { return recipe }
        let factor = Double(want) / Double(base)

        var copy = recipe
        copy.servings = want
        copy.ingredients = recipe.ingredients.map { ing in
            var scaled = ing
            scaled.amount = scaleAmount(ing.amount, by: factor)
            return scaled
        }
        return copy
    }

    /// Scale a single amount string by `factor`. Returns the original string
    /// unchanged when there's no leading number to scale.
    static func scaleAmount(_ amount: String, by factor: Double) -> String {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return amount }

        // Split leading quantity (which may be a range like "2-3" or "2 to 3")
        // from the trailing unit/text ("cups", "cloves, minced").
        guard let parsed = leadingQuantity(in: trimmed) else { return amount }

        let scaledNumbers = parsed.values.map { render($0 * factor) }
        let number = scaledNumbers.joined(separator: parsed.separator)
        let rest = parsed.remainder.trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? number : "\(number) \(rest)"
    }

    // MARK: - Parsing

    private struct Quantity {
        var values: [Double]     // one, or two for a range
        var separator: String    // "-" or " to " — preserved in output
        var remainder: String    // the unit + any trailing text
    }

    /// Pull a leading number / fraction / range off the front of `text`.
    private static func leadingQuantity(in text: String) -> Quantity? {
        let scalar = Array(text)
        var i = 0

        func readNumber() -> Double? {
            let start = i
            while i < scalar.count, scalar[i].isNumber { i += 1 }
            let firstDigits = i > start ? String(scalar[start..<i]) : ""

            // "a/b" — a plain fraction ("1/2").
            if i < scalar.count, scalar[i] == "/", !firstDigits.isEmpty {
                i += 1
                let dStart = i
                while i < scalar.count, scalar[i].isNumber { i += 1 }
                let denom = Double(String(scalar[dStart..<i])) ?? 1
                let numer = Double(firstDigits) ?? 0
                return denom == 0 ? 0 : numer / denom
            }

            // "1 1/2" — whole, space, then a fraction.
            if i < scalar.count, scalar[i] == " ", !firstDigits.isEmpty {
                var j = i + 1
                let nStart = j
                while j < scalar.count, scalar[j].isNumber { j += 1 }
                if j > nStart, j < scalar.count, scalar[j] == "/" {
                    let numer = Double(String(scalar[nStart..<j])) ?? 0
                    j += 1
                    let dStart = j
                    while j < scalar.count, scalar[j].isNumber { j += 1 }
                    let denom = Double(String(scalar[dStart..<j])) ?? 1
                    i = j
                    return (Double(firstDigits) ?? 0) + (denom == 0 ? 0 : numer / denom)
                }
            }

            // "1½" — whole immediately followed by a unicode fraction.
            if i < scalar.count, let f = unicodeFraction(scalar[i]), !firstDigits.isEmpty {
                i += 1
                return (Double(firstDigits) ?? 0) + f
            }

            // "1.5" — decimal.
            if i < scalar.count, scalar[i] == ".", !firstDigits.isEmpty {
                i += 1
                let dStart = i
                while i < scalar.count, scalar[i].isNumber { i += 1 }
                return Double(firstDigits + "." + String(scalar[dStart..<i])) ?? Double(firstDigits)
            }

            if !firstDigits.isEmpty { return Double(firstDigits) }
            return nil
        }

        // standalone leading unicode fraction ("½ tsp")
        if let f = unicodeFraction(scalar[0]) {
            i = 1
            let remainder = String(scalar[i...])
            return Quantity(values: [f], separator: " ", remainder: remainder)
        }

        guard scalar[0].isNumber else { return nil }
        guard let first = readNumber() else { return nil }

        // range? "2-3" or "2 to 3"
        var separator = ""
        var second: Double?
        let afterFirst = i
        if i < scalar.count, scalar[i] == "-" {
            i += 1
            separator = "-"
            second = readNumber()
        } else if matches(" to ", at: i, in: scalar) {
            i += 4
            separator = " to "
            second = readNumber()
        }
        if second == nil { i = afterFirst; separator = "" }

        let remainder = i <= scalar.count ? String(scalar[i...]) : ""
        var values = [first]
        if let second { values.append(second) }
        return Quantity(values: values, separator: separator.isEmpty ? " " : separator, remainder: remainder)
    }

    private static func matches(_ needle: String, at index: Int, in scalar: [Character]) -> Bool {
        let chars = Array(needle)
        guard index + chars.count <= scalar.count else { return false }
        for k in 0..<chars.count where scalar[index + k] != chars[k] { return false }
        return true
    }

    private static func unicodeFraction(_ c: Character) -> Double? {
        switch c {
        case "¼": return 0.25
        case "½": return 0.5
        case "¾": return 0.75
        case "⅓": return 1.0 / 3.0
        case "⅔": return 2.0 / 3.0
        case "⅛": return 0.125
        case "⅜": return 0.375
        case "⅝": return 0.625
        case "⅞": return 0.875
        default: return nil
        }
    }

    // MARK: - Rendering

    /// Render a scaled value back to a cook-friendly string: whole numbers stay
    /// whole; otherwise snap to the nearest common kitchen fraction.
    static func render(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        let whole = floor(value)
        let frac = value - whole

        // Snap the fractional part to the nearest 1/8 (covers ¼ ⅓ ½ ⅔ ¾).
        let eighths = (frac * 8).rounded()
        if eighths == 0 {
            return String(Int(whole))
        }
        if eighths == 8 {
            return String(Int(whole) + 1)
        }

        let glyph = fractionGlyph(eighths: Int(eighths), raw: frac)
        if whole == 0 { return glyph }
        return "\(Int(whole))\(glyph)"
    }

    private static func fractionGlyph(eighths: Int, raw: Double) -> String {
        // Prefer thirds when the raw value is clearly a third (⅓/⅔), since 1/8
        // snapping would otherwise mangle them.
        if abs(raw - 1.0 / 3.0) < 0.05 { return "⅓" }
        if abs(raw - 2.0 / 3.0) < 0.05 { return "⅔" }
        switch eighths {
        case 1: return "⅛"
        case 2: return "¼"
        case 3: return "⅜"
        case 4: return "½"
        case 5: return "⅝"
        case 6: return "¾"
        case 7: return "⅞"
        default: return ""
        }
    }
}
