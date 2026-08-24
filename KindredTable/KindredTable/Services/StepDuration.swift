import Foundation

/// Pulls a cooking duration out of a recipe step so Cook Mode can offer a
/// one-tap timer ("Simmer for 20 minutes" → a 20:00 timer).
enum StepDuration {

    /// Seconds for the first timeable duration in a step, or nil if none.
    /// Handles "20 minutes", "1 hr", ranges ("20-25 min" → 20), and the common
    /// "1 hour 30 minutes" (summed). Capped at 8 hours.
    static func seconds(in text: String) -> Int? {
        let lower = text.lowercased()
        let range = NSRange(lower.startIndex..., in: lower)

        // The optional group swallows a range ("20-25 minutes", "20 to 25 min")
        // so capture group 1 is the FIRST (lower) number — don't over-time.
        let rangeTail = "(?:\\s*[-–]\\s*\\d+|\\s+to\\s+\\d+)?"
        let hour = firstMatch(pattern: "(\\d+)\(rangeTail)\\s*(?:hours?|hrs?|hr)\\b", in: lower, range: range, multiplier: 3600)
        let minute = firstMatch(pattern: "(\\d+)\(rangeTail)\\s*(?:minutes?|mins?|min)\\b", in: lower, range: range, multiplier: 60)

        let total: Int?
        switch (hour, minute) {
        case let (h?, m?):
            if h.loc <= m.loc {
                // "1 hour 30 minutes" — minutes right after hours → sum.
                total = (m.loc - h.loc < 16) ? h.value + m.value : h.value
            } else {
                total = m.value
            }
        case let (h?, nil): total = h.value
        case let (nil, m?): total = m.value
        default: total = nil
        }

        guard let total, total > 0 else { return nil }
        return min(total, 8 * 3600)
    }

    /// mm:ss (or h:mm:ss) for a countdown display.
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private static func firstMatch(pattern: String, in text: String, range: NSRange, multiplier: Int) -> (loc: Int, value: Int)? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: range),
              let r = Range(m.range(at: 1), in: text),
              let n = Int(text[r]) else { return nil }
        return (m.range.location, n * multiplier)
    }
}
