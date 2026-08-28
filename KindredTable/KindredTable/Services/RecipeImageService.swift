import Foundation
import UIKit

/// Generates a photorealistic hero photo for a recipe using Gemini's image model
/// and caches the result to disk, so each dish is generated at most once and then
/// appears instantly everywhere (feed, detail, planner).
///
/// This is what gives KindredTable the photo-rich, magazine feel. Web-imported
/// recipes keep their real `imageURL`; AI-suggested recipes (which have no source
/// photo) get an appetizing generated one instead of a flat placeholder.
///
/// An `actor` so generation and the in-flight bookkeeping run off the main thread
/// and concurrent requests for the same dish share a single network call.
actor RecipeImageService {
    static let shared = RecipeImageService()

    /// Dedicated image-generation model — separate from the text model in `AppConfig`.
    private let model = "gemini-2.5-flash-image"
    private let apiKey: String? = AppConfig.geminiAPIKey
    private let session: URLSession = .shared

    /// Coalesces concurrent generations: two views asking for the same dish share
    /// one call rather than racing (and paying) twice.
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    /// Dishes that failed or were blocked this session — don't hammer the API
    /// retrying them on every scroll.
    private var failed: Set<String> = []

    private init() {}

    /// Whether generation is even possible (a key is configured).
    nonisolated var isAvailable: Bool { AppConfig.hasGeminiKey }

    /// Disk/memory cache hit only — never triggers a network call. Safe for the
    /// feed, where we want photos to appear once generated but never block a scroll
    /// on synthesis.
    func cachedImage(for recipe: Recipe) -> UIImage? {
        RecipeImageCache.shared.image(forKey: Self.key(for: recipe))
    }

    /// The recipe's photo, generating and caching it if missing. Coalesces
    /// concurrent requests for the same dish. Returns `nil` if there's no key,
    /// generation fails, or the content is blocked.
    ///
    /// `force` bypasses the cache and any prior-failure guard to synthesize a
    /// fresh photo (the "Generate with AI" button) — used when the cook wants a
    /// new image even though one already exists.
    func image(for recipe: Recipe, force: Bool = false) async -> UIImage? {
        let key = Self.key(for: recipe)
        if force {
            failed.remove(key)
            if let existing = inFlight[key] { return await existing.value }
            let task = Task<UIImage?, Never> { [weak self] () -> UIImage? in
                guard let self else { return nil }
                let result = await self.synthesize(for: recipe, key: key)
                await self.finish(key: key, success: result != nil)
                return result
            }
            inFlight[key] = task
            return await task.value
        }
        if let img = RecipeImageCache.shared.image(forKey: key) { return img }
        guard apiKey?.isEmpty == false, !failed.contains(key) else { return nil }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> { [weak self] () -> UIImage? in
            guard let self else { return nil }
            let result = await self.synthesize(for: recipe, key: key)
            await self.finish(key: key, success: result != nil)
            return result
        }
        inFlight[key] = task
        return await task.value
    }

    private func finish(key: String, success: Bool) {
        inFlight[key] = nil
        if !success { failed.insert(key) }
    }

    private func synthesize(for recipe: Recipe, key: String) async -> UIImage? {
        do {
            let data = try await generate(for: recipe)
            guard let image = UIImage(data: data) else { return nil }
            RecipeImageCache.shared.store(data, forKey: key)
            return image
        } catch {
            return nil
        }
    }

    // MARK: Network

    private func generate(for recipe: Recipe) async throws -> Data {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }
        let request = try makeRequest(prompt: Self.prompt(for: recipe), apiKey: apiKey)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RecipeServiceError.badResponse(status: http.statusCode,
                                                 body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(ImageResponse.self, from: data)
        guard let b64 = decoded.imageBase64, let bytes = Data(base64Encoded: b64) else {
            throw RecipeServiceError.noRecipes
        }
        return bytes
    }

    private func makeRequest(prompt: String, apiKey: String) throws -> URLRequest {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60   // image synthesis runs ~5–8s

        let payload = ImageRequest(
            contents: [.init(role: "user", parts: [.init(text: prompt)])],
            // The image model REQUIRES both modalities; a JSON responseMimeType or a
            // thinking budget makes it 404/empty. Keep the config minimal.
            generationConfig: .init(responseModalities: ["TEXT", "IMAGE"])
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    // MARK: Prompt

    private static func prompt(for recipe: Recipe) -> String {
        // Lead with the dish, ground it in a few real ingredients so the model
        // plates the right food, then a fixed photography style so every image
        // reads as one consistent, premium cookbook.
        let hero = recipe.title.trimmingCharacters(in: .whitespaces)
        let keyIngredients = recipe.ingredients
            .prefix(4)
            .map { $0.name.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        var subject = "A finished, ready-to-eat serving of \(hero)"
        if !keyIngredients.isEmpty { subject += ", featuring \(keyIngredients)" }
        if !recipe.summary.isEmpty { subject += ". \(recipe.summary)" }

        return """
        \(subject)

        Professional appetizing food photograph, natural window light, shallow depth \
        of field, plated on a simple ceramic dish on a rustic wood or stone surface, \
        fresh garnish, styled like a modern cookbook. Overhead or 45-degree angle. \
        Photorealistic, high detail. No text, no words, no watermark, no hands, no cutlery brand marks.
        """
    }

    /// Stable cache key: same dish title → same photo, everywhere.
    private static func key(for recipe: Recipe) -> String {
        var key = ""
        var lastWasDash = false
        for scalar in recipe.title.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                key.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash {
                key.append("-")
                lastWasDash = true
            }
        }
        key = key.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return key.isEmpty ? "recipe" : String(key.prefix(80))
    }
}

// MARK: - Disk + memory cache

/// Two-tier cache for generated recipe photos: an in-memory `NSCache` (fast, and
/// automatically evicted under memory pressure) backed by PNGs in the app's Caches
/// directory (survives relaunch; the OS may purge under storage pressure, and we'll
/// just regenerate). Thread-safe.
final class RecipeImageCache {
    static let shared = RecipeImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL
    private let io = DispatchQueue(label: "com.kindred.RecipeImageCache", qos: .utility)
    private let fm = FileManager.default

    private init() {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("RecipeImages", isDirectory: true)
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 120
    }

    func image(forKey key: String) -> UIImage? {
        let nsKey = key as NSString
        if let hit = memory.object(forKey: nsKey) { return hit }
        return io.sync {
            guard let data = try? Data(contentsOf: fileURL(key)),
                  let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: nsKey)
            return image
        }
    }

    func store(_ data: Data, forKey key: String) {
        if let image = UIImage(data: data) { memory.setObject(image, forKey: key as NSString) }
        io.async { [weak self] in
            guard let self else { return }
            try? data.write(to: self.fileURL(key), options: .atomic)
        }
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent(key).appendingPathExtension("png")
    }
}

// MARK: - Wire types

private struct ImageRequest: Encodable {
    struct Content: Encodable { var role: String; var parts: [Part] }
    struct Part: Encodable { var text: String }
    struct GenerationConfig: Encodable { var responseModalities: [String] }
    var contents: [Content]
    var generationConfig: GenerationConfig
}

private struct ImageResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                struct InlineData: Decodable {
                    var mimeType: String?
                    var data: String?
                }
                var inlineData: InlineData?
            }
            var parts: [Part]?
        }
        var content: Content?
    }
    var candidates: [Candidate]?

    /// First inline image payload found in the response, if any.
    var imageBase64: String? {
        candidates?
            .compactMap { $0.content?.parts }
            .flatMap { $0 }
            .compactMap { $0.inlineData?.data }
            .first
    }
}
