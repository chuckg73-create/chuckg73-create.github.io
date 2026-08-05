import Foundation

/// Runtime configuration.
///
/// The Gemini API key is never hard-coded. It is resolved, in order, from:
///   1. The `GEMINI_API_KEY` environment variable (handy for previews / CI).
///   2. A `GEMINI_API_KEY` entry in the app's Info.plist, which you can wire
///      to a build setting fed by an untracked `Secrets.xcconfig`
///      (see `Secrets.example.xcconfig`).
///
/// When no key is present the app runs in an offline "sample" mode so the UI is
/// fully explorable without network access — the same graceful-degradation
/// approach used in KindredCompass.
enum AppConfig {

    static var geminiAPIKey: String? {
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
           !plist.isEmpty,
           plist != "$(GEMINI_API_KEY)" {
            return plist
        }
        return nil
    }

    static var hasGeminiKey: Bool { geminiAPIKey != nil }

    /// Model used for recipe matching. `gemini-2.5-flash` is fast, cheap, and
    /// supports JSON response formatting. (The older 1.5-flash aliases now
    /// return 404 for freshly issued API keys.)
    static let geminiModel = "gemini-2.5-flash"
}
