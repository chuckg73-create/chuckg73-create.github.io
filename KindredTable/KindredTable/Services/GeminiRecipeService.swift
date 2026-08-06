import Foundation

/// Errors surfaced by the recipe-matching flow.
enum RecipeServiceError: LocalizedError {
    case emptyPantry
    case missingAPIKey
    case badResponse(status: Int, body: String)
    case decoding(String)
    case noRecipes

    var errorDescription: String? {
        switch self {
        case .emptyPantry:
            return "Add a few ingredients first — snap a photo of your fridge or add them by hand."
        case .missingAPIKey:
            return "No Gemini API key is configured, so Kindred Kitchen is showing sample ideas. Add a key to get suggestions tailored to your pantry."
        case .badResponse(let status, let body):
            let detail = Self.humanReadableDetail(from: body)
            if detail.isEmpty {
                return "The recipe service returned an error (\(status)). Please try again in a moment."
            }
            return "The recipe service returned an error (\(status)): \(detail)"
        case .decoding(let detail):
            return "Couldn't read the suggestions (\(detail)). Please try again."
        case .noRecipes:
            return "No matching recipes came back this time. Try adding another ingredient or two."
        }
    }

    /// Pull Google's human-readable `error.message` out of an error response body,
    /// falling back to a trimmed snippet.
    static func humanReadableDetail(from body: String) -> String {
        guard let data = body.data(using: .utf8) else { return "" }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return String(message.prefix(200))
        }
        return String(body.prefix(200))
    }
}

/// Talks to Google's Gemini `generateContent` endpoint to turn a pantry + taste
/// profile into ranked meal suggestions.
///
/// This mirrors the KindredCompass Gemini integration: build a prompt from the
/// user's locally-stored profile (no personal identifiers), POST it to the REST
/// endpoint with `URLSession`, ask for strict JSON, then decode the payload into
/// domain models. When no API key is available it falls back to on-device sample
/// suggestions so the experience never dead-ends.
struct GeminiRecipeService {

    var apiKey: String? = AppConfig.geminiAPIKey
    var model: String = AppConfig.geminiModel
    var session: URLSession = .shared

    // MARK: Public API

    /// Generate up to `count` meal suggestions for today.
    func suggestRecipes(
        from ingredients: [Ingredient],
        profile: TasteProfile,
        count: Int = 6
    ) async throws -> [Recipe] {
        guard !ingredients.isEmpty else { throw RecipeServiceError.emptyPantry }

        guard let apiKey, !apiKey.isEmpty else {
            // Graceful offline mode.
            return SampleData.sampleRecipes(for: ingredients, profile: profile, count: count)
        }

        let prompt = Self.buildPrompt(ingredients: ingredients, profile: profile, count: count)
        let request = try makeRequest(prompt: prompt, apiKey: apiKey)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RecipeServiceError.badResponse(status: http.statusCode, body: body)
        }

        let text = try Self.extractText(from: data)
        let recipes = try Self.decodeRecipes(from: text)
        guard !recipes.isEmpty else { throw RecipeServiceError.noRecipes }

        return recipes
            .sorted { $0.matchScore > $1.matchScore }
    }

    /// Identify food ingredients in a photo using Gemini's vision capability.
    /// Far more accurate on cluttered fridge/pantry shots than the on-device
    /// classifier, at the cost of sending the image to the model.
    func identifyIngredients(in jpegData: Data) async throws -> [Ingredient] {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let request = try makeVisionRequest(jpegData: jpegData, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RecipeServiceError.badResponse(status: http.statusCode, body: body)
        }

        let text = try Self.extractText(from: data)
        let names = try Self.decodeIngredientNames(from: text)
        return names.map {
            Ingredient(name: $0, category: FoodVocabulary.categorize($0), confidence: 0.9)
        }
    }

    // MARK: Request construction

    private func makeVisionRequest(jpegData: Data, apiKey: String) throws -> URLRequest {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let prompt = """
        This is a photo of a fridge, freezer, or pantry. List every distinct food \
        ingredient you can identify. Use simple grocery names (e.g. "eggs", \
        "cheddar cheese", "spinach", "ground beef", "ketchup"). No brand names, no \
        quantities, no packaging words, no duplicates. If you cannot identify any \
        food, return an empty list.
        Respond with ONLY this JSON: {"ingredients": ["name", ...]}
        """

        let payload = GeminiRequest(
            contents: [
                .init(role: "user", parts: [
                    .init(text: prompt),
                    .init(inlineData: .init(mimeType: "image/jpeg", data: jpegData.base64EncodedString())),
                ])
            ],
            generationConfig: .init(
                temperature: 0.2,
                topP: 0.95,
                maxOutputTokens: 1024,
                responseMimeType: "application/json",
                thinkingConfig: .init(thinkingBudget: 0)
            )
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    // MARK: Request construction (recipes)

    private func makeRequest(prompt: String, apiKey: String) throws -> URLRequest {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let payload = GeminiRequest(
            contents: [
                .init(role: "user", parts: [.init(text: prompt)])
            ],
            generationConfig: .init(
                temperature: 0.7,
                topP: 0.95,
                maxOutputTokens: 8192,
                responseMimeType: "application/json",
                // Gemini 2.5 models "think" by default, which can consume the
                // whole output budget before any JSON is written. Disable it so
                // the full budget goes to the recipe payload.
                thinkingConfig: .init(thinkingBudget: 0)
            )
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    // MARK: Prompt

    static func buildPrompt(ingredients: [Ingredient], profile: TasteProfile, count: Int) -> String {
        let onHand = ingredients
            .map { item -> String in
                if let q = item.quantity, !q.isEmpty { return "\(item.name) (\(q))" }
                return item.name
            }
            .joined(separator: ", ")

        var lines: [String] = []
        lines.append("You are the recipe-matching engine for KindredTable, an app that suggests meals from what a home cook already has.")
        lines.append("Suggest \(count) meal ideas that lean heavily on the ingredients on hand and fit the cook's taste profile.")
        lines.append("")
        lines.append("INGREDIENTS ON HAND: \(onHand)")
        lines.append("")
        lines.append("TASTE PROFILE:")
        if !profile.diets.isEmpty {
            lines.append("- Diets: \(profile.diets.map(\.title).sorted().joined(separator: ", "))")
        }
        if !profile.lovedCuisines.isEmpty {
            lines.append("- Loves cuisines: \(profile.lovedCuisines.joined(separator: ", "))")
        }
        if !profile.dislikedIngredients.isEmpty {
            lines.append("- Dislikes / avoid: \(profile.dislikedIngredients.joined(separator: ", "))")
        }
        if !profile.allergens.isEmpty {
            lines.append("- ALLERGENS to strictly exclude: \(profile.allergens.joined(separator: ", "))")
        }
        lines.append("- Spice preference: \(profile.spiceLevel.title)")
        lines.append("- Cooking skill: \(profile.skill.title)")
        lines.append("- Max cook time: \(profile.maxCookMinutes) minutes")
        if !profile.equipment.isEmpty {
            lines.append("- Available equipment: \(profile.equipment.joined(separator: ", "))")
        }
        if !profile.notes.isEmpty {
            lines.append("- Notes: \(profile.notes)")
        }
        lines.append("")
        lines.append("RULES:")
        lines.append("- Prioritise recipes that use the most on-hand ingredients and the fewest new purchases.")
        lines.append("- Never include any listed allergen. Respect all diet restrictions.")
        lines.append("- Keep cook time at or under the max where possible; if not, keep it close.")
        lines.append("- 'needsToBuy' should list at most 4 common extra items.")
        lines.append("- 'matchScore' is an integer 0-100 reflecting fit to pantry AND taste.")
        lines.append("- 'whyYoullLikeIt' is one short sentence referencing the cook's taste.")
        if !profile.equipment.isEmpty {
            lines.append("- Favor methods the listed equipment enables and name the appliance in the steps where it helps (e.g. air fryer, pellet smoker, sous vide, griddle).")
        }
        lines.append("")
        lines.append("Respond with ONLY a JSON object of this exact shape, no markdown:")
        lines.append("""
        {
          "recipes": [
            {
              "title": "string",
              "summary": "one-sentence description",
              "mealType": "breakfast|lunch|dinner|snack|dessert",
              "usesOnHand": ["ingredient", ...],
              "needsToBuy": ["ingredient", ...],
              "steps": ["step 1", "step 2", ...],
              "cookMinutes": 20,
              "difficulty": "easy|medium|involved",
              "tags": ["tag", ...],
              "matchScore": 0,
              "whyYoullLikeIt": "string"
            }
          ]
        }
        """)
        return lines.joined(separator: "\n")
    }

    // MARK: Response decoding

    /// Pull the model's text out of the Gemini candidate envelope, with
    /// diagnostic errors when the model returns no usable content.
    static func extractText(from data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let block = decoded.promptFeedback?.blockReason {
            throw RecipeServiceError.decoding("blocked: \(block)")
        }
        guard let candidate = decoded.candidates?.first else {
            throw RecipeServiceError.decoding("no candidates returned")
        }
        let text = candidate.content?.parts?.compactMap(\.text).joined()
        guard let text, !text.isEmpty else {
            throw RecipeServiceError.decoding("empty response, finishReason: \(candidate.finishReason ?? "unknown")")
        }
        return text
    }

    /// Decode the recipe JSON the model produced, tolerating stray markdown fences.
    static func decodeRecipes(from text: String) throws -> [Recipe] {
        let json = sanitizedJSON(text)
        guard let data = json.data(using: .utf8) else {
            throw RecipeServiceError.decoding("not utf8")
        }
        do {
            let payload = try JSONDecoder().decode(RecipePayload.self, from: data)
            return payload.recipes.map { $0.toRecipe() }
        } catch {
            throw RecipeServiceError.decoding("bad JSON near: \(String(json.prefix(80)))")
        }
    }

    /// Decode the `{"ingredients": [...]}` payload from a vision response,
    /// trimming and de-duplicating names.
    static func decodeIngredientNames(from text: String) throws -> [String] {
        struct Payload: Decodable { var ingredients: [String] }
        let json = sanitizedJSON(text)
        guard let data = json.data(using: .utf8) else {
            throw RecipeServiceError.decoding("not utf8")
        }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            var seen = Set<String>()
            var result: [String] = []
            for raw in payload.ingredients {
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
                result.append(name)
            }
            return result
        } catch {
            throw RecipeServiceError.decoding("bad JSON near: \(String(json.prefix(80)))")
        }
    }

    /// Strip ```json fences and isolate the outermost JSON object if the model
    /// wrapped it in prose.
    static func sanitizedJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
            s = s.replacingOccurrences(of: "```", with: "")
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            s = String(s[start...end])
        }
        return s
    }
}

// MARK: - Wire types (request)

private struct GeminiRequest: Encodable {
    struct Content: Encodable {
        var role: String
        var parts: [Part]
    }
    struct Part: Encodable {
        var text: String? = nil
        var inlineData: InlineData? = nil
    }
    struct InlineData: Encodable {
        var mimeType: String
        var data: String
    }
    struct GenerationConfig: Encodable {
        var temperature: Double
        var topP: Double
        var maxOutputTokens: Int
        var responseMimeType: String
        var thinkingConfig: ThinkingConfig?
    }
    struct ThinkingConfig: Encodable {
        var thinkingBudget: Int
    }
    var contents: [Content]
    var generationConfig: GenerationConfig
}

// MARK: - Wire types (response)

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { var text: String? }
            var parts: [Part]?
        }
        var content: Content?
        var finishReason: String?
    }
    struct PromptFeedback: Decodable {
        var blockReason: String?
    }
    var candidates: [Candidate]?
    var promptFeedback: PromptFeedback?
}

// MARK: - Recipe payload

private struct RecipePayload: Decodable {
    var recipes: [Item]

    struct Item: Decodable {
        var title: String
        var summary: String?
        var mealType: String?
        var usesOnHand: [String]?
        var needsToBuy: [String]?
        var steps: [String]?
        var cookMinutes: Int?
        var difficulty: String?
        var tags: [String]?
        var matchScore: Int?
        var whyYoullLikeIt: String?

        func toRecipe() -> Recipe {
            Recipe(
                title: title,
                summary: summary ?? "",
                mealType: MealType(rawValue: (mealType ?? "dinner").lowercased()) ?? .dinner,
                usesOnHand: usesOnHand ?? [],
                needsToBuy: needsToBuy ?? [],
                steps: steps ?? [],
                cookMinutes: cookMinutes ?? 20,
                difficulty: Difficulty(rawValue: (difficulty ?? "easy").lowercased()) ?? .easy,
                tags: tags ?? [],
                matchScore: min(100, max(0, matchScore ?? 0)),
                whyYoullLikeIt: whyYoullLikeIt ?? ""
            )
        }
    }
}
