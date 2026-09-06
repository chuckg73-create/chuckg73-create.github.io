import Foundation

/// Runtime configuration.
///
/// All Gemini calls are proxied through the KindredTable Cloudflare Worker so the
/// API key never ships in the app bundle. The Worker injects the key server-side.
///
/// When no Worker URL is configured (local dev without the Worker) the app falls
/// back to a direct Gemini call using GEMINI_API_KEY from the environment or plist
/// (Secrets.xcconfig). In production builds only the Worker URL is set.
enum AppConfig {

    /// Production Worker endpoint. Change this after `wrangler deploy` prints the URL.
    static let workerURL = "https://kindredtable-api.chuckg73.workers.dev"

    /// Direct key fallback — only used in local dev if workerURL is unreachable.
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

    static var hasGeminiKey: Bool { true } // Worker is always available in production

    /// Model used for recipe matching.
    static let geminiModel = "gemini-2.5-flash"
    static let geminiImageModel = "gemini-2.5-flash-image"
}
