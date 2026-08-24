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
            return "No Gemini API key is configured, so KindredTable is showing sample ideas. Add a key to get suggestions tailored to your pantry."
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
        count: Int = 6,
        servings: Int? = nil,
        special: Bool = false,
        tasteFeedback: String? = nil
    ) async throws -> [Recipe] {
        guard !ingredients.isEmpty else { throw RecipeServiceError.emptyPantry }

        guard let apiKey, !apiKey.isEmpty else {
            // Graceful offline mode.
            return SampleData.sampleRecipes(for: ingredients, profile: profile, count: count)
        }

        let prompt = Self.buildPrompt(ingredients: ingredients, profile: profile, count: count, servings: servings, special: special, tasteFeedback: tasteFeedback)
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
        // Safety backstop: never surface a recipe that slipped past the
        // prompt's hard dietary/allergen rules.
        let safe = profile.compliantRecipes(from: recipes)
        guard !safe.isEmpty else { throw RecipeServiceError.noRecipes }

        return safe
            .sorted { $0.matchScore > $1.matchScore }
    }

    /// Generate a specific dish the user asked for (e.g. "london broil"), tuned
    /// to their taste, with a built-in shopping list (ingredients they lack are
    /// marked haveIt=false).
    func craveRecipes(
        dish: String,
        from ingredients: [Ingredient],
        profile: TasteProfile,
        count: Int = 2,
        servings: Int? = nil
    ) async throws -> [Recipe] {
        let wanted = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { throw RecipeServiceError.noRecipes }
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let prompt = Self.buildPrompt(ingredients: ingredients, profile: profile, count: count, craving: wanted, servings: servings)
        let request = try makeRequest(prompt: prompt, apiKey: apiKey)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RecipeServiceError.badResponse(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let text = try Self.extractText(from: data)
        let recipes = try Self.decodeRecipes(from: text)
        // Same safety backstop as the feed: hard rules hold for cravings too.
        let safe = profile.compliantRecipes(from: recipes)
        guard !safe.isEmpty else { throw RecipeServiceError.noRecipes }
        return safe.sorted { $0.matchScore > $1.matchScore }
    }

    /// Flexible recipe request: build around chosen ingredients, a course
    /// (side, soup, salad…), and specific equipment, optionally leaning on the
    /// pantry. Reuses the same rich schema + dietary hard rules.
    func makeMeal(
        _ request: MealRequest,
        from ingredients: [Ingredient],
        profile: TasteProfile,
        count: Int = 3,
        servings: Int? = nil,
        special: Bool = false,
        tasteFeedback: String? = nil
    ) async throws -> [Recipe] {
        guard !request.isEmpty else { throw RecipeServiceError.noRecipes }
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let dish = request.dish.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = Self.buildPrompt(
            ingredients: ingredients,
            profile: profile,
            count: count,
            craving: dish.isEmpty ? nil : dish,
            includeIngredients: request.includeIngredients,
            course: request.course.promptPhrase,
            useEquipment: request.equipment,
            preferOnHand: request.preferOnHand,
            servings: servings,
            special: special,
            tasteFeedback: tasteFeedback
        )
        let req = try makeRequest(prompt: prompt, apiKey: apiKey)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RecipeServiceError.badResponse(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let text = try Self.extractText(from: data)
        let recipes = try Self.decodeRecipes(from: text)
        guard !recipes.isEmpty else { throw RecipeServiceError.noRecipes }
        return recipes.sorted { $0.matchScore > $1.matchScore }
    }

    /// Import a recipe from a web page's reduced text (JSON-LD + visible text).
    /// Transcribes the single main recipe faithfully, ignores nav/ads/comments,
    /// and marks it imported with the site as attribution.
    func importRecipe(fromWebText pageText: String, sourceLabel: String) async throws -> Recipe {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let prompt = Self.buildWebImportPrompt(pageText: pageText)
        let request = try makeRequest(prompt: prompt, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RecipeServiceError.badResponse(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let text = try Self.extractText(from: data)
        let recipes = try Self.decodeRecipes(from: text)
        guard var recipe = recipes.first else { throw RecipeServiceError.noRecipes }
        recipe.source = .imported
        recipe.matchScore = 0
        if recipe.sourceNote.trimmingCharacters(in: .whitespaces).isEmpty {
            recipe.sourceNote = sourceLabel
        }
        return recipe
    }

    // MARK: Ingredient substitution

    /// Suggest `count` realistic swaps for one ingredient in a recipe, honoring
    /// the cook's diets/allergens/dislikes and the given reason.
    func suggestSubstitutions(
        for ingredient: RecipeIngredient,
        in recipe: Recipe,
        reason: String,
        profile: TasteProfile,
        count: Int = 3
    ) async throws -> [SubstitutionOption] {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        var lines: [String] = []
        lines.append("In the recipe \"\(recipe.title)\" (\(recipe.summary)), the cook wants to replace this ingredient: \"\(ingredient.display)\".")
        if !reason.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("Reason: \(reason).")
        }
        lines.append("Suggest \(count) realistic substitutes that work in THIS dish. For each: the item name, an amount appropriate to the recipe (serves \(recipe.servings)), and one short reason it works.")
        lines.append(Self.dietaryConstraintLine(profile))
        lines.append("Do NOT suggest anything that breaks those rules or that the cook dislikes.")
        lines.append("Respond with ONLY this JSON: {\"options\":[{\"name\":\"black beans\",\"amount\":\"1 can, drained\",\"note\":\"hearty and vegetarian\"}]}")

        let request = try makeRequest(prompt: lines.joined(separator: "\n"), apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RecipeServiceError.badResponse(status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                                 body: String(data: data, encoding: .utf8) ?? "")
        }
        let text = try Self.extractText(from: data)
        return try Self.decodeSubstitutions(from: text)
    }

    /// Apply a swap (or removal) and return the updated recipe with steps/tips
    /// rewritten to match. Pass `replacement == nil` to remove the ingredient.
    func applySubstitution(
        in recipe: Recipe,
        replacing original: RecipeIngredient,
        with replacement: SubstitutionOption?,
        reason: String,
        profile: TasteProfile
    ) async throws -> Recipe {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        var lines: [String] = []
        if let replacement {
            lines.append("Update this recipe by replacing \"\(original.display)\" with \"\(replacement.amount) \(replacement.name)\".")
        } else {
            lines.append("Update this recipe by REMOVING \"\(original.display)\" entirely.")
        }
        if !reason.trimmingCharacters(in: .whitespaces).isEmpty { lines.append("Reason: \(reason).") }
        lines.append("Rewrite the ingredients AND the method steps (and tips) so they reflect the change — remove or adjust any step that referenced the old ingredient. Keep everything else the same: title, servings=\(recipe.servings), style. Re-estimate nutrition.")
        lines.append(Self.dietaryConstraintLine(profile))
        lines.append("")
        lines.append("CURRENT RECIPE:")
        lines.append("Title: \(recipe.title)")
        lines.append("Summary: \(recipe.summary)")
        lines.append("Ingredients:")
        for ing in recipe.ingredients { lines.append("- \(ing.display)") }
        lines.append("Steps:")
        for (i, s) in recipe.steps.enumerated() { lines.append("\(i + 1). \(s)") }
        if !recipe.tips.isEmpty {
            lines.append("Tips:")
            for t in recipe.tips { lines.append("- \(t)") }
        }
        lines.append("")
        lines.append("Respond with ONLY the full updated recipe as JSON of this shape, no markdown:")
        lines.append("""
        {
          "title": "string",
          "summary": "one sentence",
          "mealType": "breakfast|lunch|dinner|snack|dessert",
          "servings": \(recipe.servings),
          "prepMinutes": 0, "cookMinutes": 0,
          "ingredients": [ { "name": "", "amount": "", "haveIt": false } ],
          "steps": ["step"], "tips": ["tip"],
          "difficulty": "easy|medium|involved", "tags": ["tag"],
          "matchScore": 0, "whyYoullLikeIt": "",
          "timeline": [],
          "nutrition": { "calories": 0, "protein": 0, "carbs": 0, "fat": 0 }
        }
        """)

        let request = try makeRequest(prompt: lines.joined(separator: "\n"), apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RecipeServiceError.badResponse(status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                                 body: String(data: data, encoding: .utf8) ?? "")
        }
        let text = try Self.extractText(from: data)
        guard var updated = try Self.decodeRecipes(from: text).first else { throw RecipeServiceError.noRecipes }
        // Carry over identity + provenance the model doesn't know about.
        updated.id = recipe.id
        updated.source = recipe.source
        updated.sourceNote = recipe.sourceNote
        updated.imageURL = recipe.imageURL
        return updated
    }

    /// One line stating the cook's hard dietary rules for substitution prompts.
    static func dietaryConstraintLine(_ profile: TasteProfile) -> String {
        var parts: [String] = []
        if !profile.diets.isEmpty { parts.append("diets: " + profile.diets.map(\.title).joined(separator: ", ")) }
        if !profile.allergens.isEmpty { parts.append("allergens to avoid entirely: " + profile.allergens.joined(separator: ", ")) }
        if !profile.dislikedIngredients.isEmpty { parts.append("dislikes: " + profile.dislikedIngredients.joined(separator: ", ")) }
        return parts.isEmpty ? "The cook has no strict dietary restrictions." : "HARD RULES — " + parts.joined(separator: "; ") + "."
    }

    static func decodeSubstitutions(from text: String) throws -> [SubstitutionOption] {
        struct Payload: Decodable { struct Opt: Decodable { var name: String; var amount: String?; var note: String? }; var options: [Opt]? }
        let json = sanitizedJSON(text)
        guard let data = json.data(using: .utf8) else { throw RecipeServiceError.decoding("not utf8") }
        do {
            let p = try JSONDecoder().decode(Payload.self, from: data)
            return (p.options ?? []).compactMap { o in
                let name = o.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return SubstitutionOption(name: name,
                                          amount: (o.amount ?? "").trimmingCharacters(in: .whitespaces),
                                          note: (o.note ?? "").trimmingCharacters(in: .whitespaces))
            }
        } catch {
            throw RecipeServiceError.decoding("bad JSON near: \(String(json.prefix(80)))")
        }
    }

    static func buildWebImportPrompt(pageText: String) -> String {
        var lines: [String] = []
        lines.append("Below is text scraped from a recipe web page — it may include schema.org JSON-LD structured data, plus navigation, ads, and comments. Extract the SINGLE main recipe and return it as JSON. Rules:")
        lines.append("- If schema.org/Recipe JSON-LD is present, PREFER it for the title, ingredients, steps, yield and times.")
        lines.append("- Transcribe faithfully: keep ingredient amounts as written, don't invent or substitute. Ignore ads, related-recipe lists, comments, and navigation.")
        lines.append("- Put each ingredient's amount in `amount` and the item in `name`; set every `haveIt` to false.")
        lines.append("- Preserve the method as ordered `steps` (expand tsp/tbsp, keep temps and times). `tips` may capture author notes; else [].")
        lines.append("- Read servings/yield if stated, else estimate an integer. `timeline`: []. `matchScore`: 0. `mealType`: best guess.")
        lines.append("- If there is no real recipe on the page, return {\"recipes\": []}.")
        lines.append("Respond with ONLY this JSON, no markdown:")
        lines.append("""
        {
          "recipes": [
            {
              "title": "string",
              "summary": "one-sentence description",
              "mealType": "breakfast|lunch|dinner|snack|dessert",
              "servings": 4,
              "prepMinutes": 0,
              "cookMinutes": 0,
              "ingredients": [ { "name": "flour", "amount": "2 cups", "haveIt": false } ],
              "steps": ["step 1", "step 2"],
              "tips": [],
              "difficulty": "easy|medium|involved",
              "tags": ["tag"],
              "matchScore": 0,
              "whyYoullLikeIt": "",
              "timeline": []
            }
          ]
        }
        """)
        lines.append("")
        lines.append("PAGE CONTENT:")
        lines.append(pageText)
        return lines.joined(separator: "\n")
    }

    /// Read a photographed recipe (a handwritten card, a magazine clipping, a
    /// printout) into a structured Recipe for the cook's cookbook. Transcribes
    /// faithfully — it does not invent or substitute — and marks the result as
    /// imported so it sits alongside the app's own finds.
    func importRecipe(from jpegData: Data) async throws -> Recipe {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let request = try makeRecipeVisionRequest(jpegData: jpegData, apiKey: apiKey)
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
        guard var recipe = recipes.first else { throw RecipeServiceError.noRecipes }
        recipe.source = .imported
        recipe.matchScore = 0   // an imported recipe isn't scored against the pantry
        return recipe
    }

    /// Polish an imported (handwritten / clipped) recipe WITHOUT rewriting it:
    /// add practical chef tips tuned to the cook's kit, and flag gaps the
    /// original left out (missing oven temp, vague "a pinch", an ingredient that
    /// never appears in the steps). Returns the same recipe with `tips` and
    /// `cooksNotes` filled — the title, ingredients and steps are untouched.
    func enrich(_ recipe: Recipe, profile: TasteProfile) async throws -> Recipe {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let prompt = Self.buildEnrichmentPrompt(recipe: recipe, profile: profile)
        let request = try makeRequest(prompt: prompt, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RecipeServiceError.badResponse(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let text = try Self.extractText(from: data)
        let (tips, notes) = try Self.decodeEnrichment(from: text)

        var polished = recipe
        // Merge tips (dedupe, case-insensitive), keep any the card already had.
        var seen = Set(recipe.tips.map { $0.lowercased() })
        for tip in tips where seen.insert(tip.lowercased()).inserted {
            polished.tips.append(tip)
        }
        polished.cooksNotes = notes
        return polished
    }

    static func buildEnrichmentPrompt(recipe: Recipe, profile: TasteProfile) -> String {
        var lines: [String] = []
        lines.append("You are helping a home cook with a recipe they photographed from a handwritten card or clipping. Do NOT rewrite it, rename it, or change the ingredients or steps — the cook wants their family recipe preserved exactly. Your job is only to ADD help alongside it.")
        lines.append("")
        lines.append("RECIPE: \(recipe.title)")
        lines.append("Serves \(recipe.servings).")
        lines.append("Ingredients:")
        for ing in recipe.ingredients {
            lines.append("- \(ing.display)")
        }
        lines.append("Steps:")
        for (i, step) in recipe.steps.enumerated() {
            lines.append("\(i + 1). \(step)")
        }
        if !profile.equipment.isEmpty {
            lines.append("")
            lines.append("The cook's equipment: \(profile.equipment.joined(separator: ", ")). Tailor tips to this gear where relevant.")
        }
        lines.append("")
        lines.append("Return TWO things as JSON:")
        lines.append("- \"tips\": 3-5 short, practical chef tips/hints for making THIS dish well (doneness cues, make-ahead, easy swaps, storage, how to level it up). Reference the cook's equipment where it helps.")
        lines.append("- \"notes\": things a handwritten recipe often leaves out or states vaguely — ONLY where genuinely missing or ambiguous. Each note names the gap and gives a sensible, clearly-marked suggestion. Examples: \"No oven temperature is written — banana bread is usually baked at 350°F/175°C.\", \"'A pinch of salt' is about 1/4 tsp.\", \"The steps mention butter but no amount is listed — try 1/2 cup.\" If nothing is missing, return an empty array. Do NOT invent problems.")
        lines.append("Respond with ONLY this JSON, no markdown:")
        lines.append("{ \"tips\": [\"...\"], \"notes\": [\"...\"] }")
        return lines.joined(separator: "\n")
    }

    static func decodeEnrichment(from text: String) throws -> (tips: [String], notes: [String]) {
        struct Payload: Decodable { var tips: [String]?; var notes: [String]? }
        let json = sanitizedJSON(text)
        guard let data = json.data(using: .utf8) else { throw RecipeServiceError.decoding("not utf8") }
        do {
            let p = try JSONDecoder().decode(Payload.self, from: data)
            let clean: ([String]?) -> [String] = { ($0 ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
            return (clean(p.tips), clean(p.notes))
        } catch {
            throw RecipeServiceError.decoding("bad JSON near: \(String(json.prefix(80)))")
        }
    }

    /// Identify food ingredients in a photo using Gemini's vision capability.
    /// Far more accurate on cluttered fridge/pantry shots than the on-device
    /// classifier, at the cost of sending the image to the model.
    func identifyIngredients(in jpegData: Data) async throws -> [Ingredient] {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let prompt = """
        This is a photo of a fridge, freezer, or pantry. List every distinct food \
        ingredient you can identify. Use simple grocery names (e.g. "eggs", \
        "cheddar cheese", "spinach", "ground beef", "ketchup"). No brand names, no \
        quantities, no packaging words, no duplicates. If you cannot identify any \
        food, return an empty list.
        Respond with ONLY this JSON: {"items": ["name", ...]}
        """
        let names = try await runVision(prompt: prompt, jpegData: jpegData, apiKey: apiKey)
        return names.map {
            Ingredient(name: $0, category: FoodVocabulary.categorize($0), confidence: 0.9)
        }
    }

    /// Identify cooking equipment/appliances in a photo of the cook's kitchen —
    /// so recipe steps can be written for exactly what they own (their rice
    /// cooker, air fryer, smoker) instead of a hand-typed list.
    func identifyEquipment(in jpegData: Data) async throws -> [String] {
        guard let apiKey, !apiKey.isEmpty else { throw RecipeServiceError.missingAPIKey }

        let prompt = """
        This is a photo of a kitchen. List the distinct COOKING EQUIPMENT and \
        APPLIANCES you can identify that affect how food is cooked — e.g. "Oven", \
        "Stovetop", "Air fryer", "Instant Pot", "Slow cooker", "Rice cooker", \
        "Stand mixer", "Blender", "Food processor", "Cast iron skillet", \
        "Grill", "Smoker", "Sous vide", "Toaster oven", "Microwave", "Dutch oven", \
        "Wok". Use short generic names (no brands — say "Pressure cooker" not \
        "Instant Pot Duo"; "Grill" or "Smoker" not "Traeger"). Only list what you \
        can actually see. No cookware that doesn't change method (plates, cups), no \
        duplicates. If you can't identify any, return an empty list.
        Respond with ONLY this JSON: {"items": ["name", ...]}
        """
        return try await runVision(prompt: prompt, jpegData: jpegData, apiKey: apiKey)
    }

    /// Shared vision round-trip: POST a prompt + image, decode a `{"items":[…]}`
    /// string list (trimmed, de-duplicated).
    private func runVision(prompt: String, jpegData: Data, apiKey: String) async throws -> [String] {
        let request = try makeVisionRequest(jpegData: jpegData, apiKey: apiKey, prompt: prompt)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RecipeServiceError.badResponse(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RecipeServiceError.badResponse(status: http.statusCode, body: body)
        }
        let text = try Self.extractText(from: data)
        return try Self.decodeStringList(from: text)
    }

    // MARK: Request construction

    private func makeVisionRequest(jpegData: Data, apiKey: String, prompt: String) throws -> URLRequest {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

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

    private func makeRecipeVisionRequest(jpegData: Data, apiKey: String) throws -> URLRequest {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let prompt = """
        This photo shows a recipe — it may be handwritten (a family recipe card), \
        a magazine clipping, a cookbook page, or a printout. Transcribe it FAITHFULLY \
        into structured JSON. Do NOT invent, substitute, or "improve" anything: use \
        the exact ingredients, amounts, and steps as written. Rules:
        - Keep every ingredient amount exactly as written ("1 1/2 cups", "1 stick", \
        "to taste"). Put the amount in `amount` and the item in `name`.
        - Set every ingredient's `haveIt` to false.
        - Preserve the method as an ordered list of `steps`, lightly cleaned up for \
        readability (expand obvious abbreviations like tsp/tbsp, keep temperatures and times).
        - If a title is written, use it; otherwise create a short descriptive one.
        - Read the servings/yield if stated; otherwise estimate a sensible integer.
        - `tips` may capture any notes written on the card ("Grandma's note: …"); else [].
        - `timeline` may be []. `matchScore` = 0. `mealType` = your best guess.
        - If the image is not a readable recipe, return {"recipes": []}.
        Respond with ONLY this JSON, no markdown:
        {
          "recipes": [
            {
              "title": "string",
              "summary": "one-sentence description",
              "mealType": "breakfast|lunch|dinner|snack|dessert",
              "servings": 4,
              "prepMinutes": 0,
              "cookMinutes": 0,
              "ingredients": [ { "name": "flour", "amount": "2 cups", "haveIt": false } ],
              "steps": ["step 1", "step 2"],
              "tips": [],
              "difficulty": "easy|medium|involved",
              "tags": ["tag"],
              "matchScore": 0,
              "whyYoullLikeIt": "",
              "timeline": []
            }
          ]
        }
        """

        let payload = GeminiRequest(
            contents: [
                .init(role: "user", parts: [
                    .init(text: prompt),
                    .init(inlineData: .init(mimeType: "image/jpeg", data: jpegData.base64EncodedString())),
                ])
            ],
            generationConfig: .init(
                temperature: 0.1,
                topP: 0.95,
                maxOutputTokens: 8192,
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
                // Six rich recipes (detailed steps + tips + timeline + nutrition)
                // land right at the old 8192 cap and truncated intermittently
                // (finishReason MAX_TOKENS → invalid JSON). Give ample headroom.
                maxOutputTokens: 20000,
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

    static func buildPrompt(
        ingredients: [Ingredient],
        profile: TasteProfile,
        count: Int,
        craving: String? = nil,
        includeIngredients: [String] = [],
        course: String? = nil,
        useEquipment: [String] = [],
        preferOnHand: Bool = false,
        servings: Int? = nil,
        special: Bool = false,
        tasteFeedback: String? = nil
    ) -> String {
        let onHand = ingredients
            .map { item -> String in
                if let q = item.quantity, !q.isEmpty { return "\(item.name) (\(q))" }
                return item.name
            }
            .joined(separator: ", ")

        var lines: [String] = []
        if let craving, !craving.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("You are the recipe engine for KindredTable. The home cook specifically wants to make: \(craving).")
            lines.append("Create \(count) excellent version(s) of \(craving), tuned to the cook's taste profile below.")
            lines.append("Mark ingredients they already have as haveIt=true; list everything else as haveIt=false so it forms their shopping list. It's fine if most ingredients must be bought.")
        } else {
            lines.append("You are the recipe-matching engine for KindredTable, an app that suggests meals from what a home cook already has.")
            lines.append("Suggest \(count) meal ideas that lean heavily on the ingredients on hand and fit the cook's taste profile.")
        }
        if let servings, servings > 0 {
            lines.append("SERVINGS: cook for exactly \(servings) \(servings == 1 ? "person" : "people"). Set servings=\(servings) on every recipe and scale ALL ingredient amounts to feed \(servings) (do not default to 2 or 4). Portion the protein and sides accordingly.")
        }
        if special {
            lines.append("SPECIAL OCCASION — this is a date-night dinner. Make it feel restaurant-special, not everyday: choose an impressive but achievable main (a nicer cut or protein), an elegant plate, and a little wow factor. In 'tips', include a simple dessert idea and a drink or wine pairing. Keep it romantic and memorable while still respecting the taste profile and hard dietary rules.")
        }
        if let tasteFeedback, !tasteFeedback.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append(tasteFeedback)
        }
        if !includeIngredients.isEmpty {
            lines.append("MUST USE: build the dish around these ingredients the cook chose — \(includeIngredients.joined(separator: ", ")). They should be central to the dish, not garnishes.")
        }
        if let course, !course.isEmpty {
            lines.append("COURSE: every result must be \(course).")
        }
        if !useEquipment.isEmpty {
            lines.append("EQUIPMENT: prepare it primarily using the cook's \(useEquipment.joined(separator: ", ")); write the steps for that equipment with exact settings and times.")
        }
        if preferOnHand {
            lines.append("Lean heavily on the ON HAND ingredients and keep new purchases (haveIt=false) to a minimum.")
        }
        lines.append("")
        lines.append("INGREDIENTS ON HAND: \(onHand)")
        lines.append("")
        lines.append("TASTE PROFILE:")
        // Diets and allergens are stated once, in the HARD DIETARY RULES block
        // below, so the model gets a single authoritative version of each.
        if !profile.lovedCuisines.isEmpty {
            lines.append("- Loves cuisines: \(profile.lovedCuisines.joined(separator: ", "))")
        }
        if !profile.dislikedIngredients.isEmpty {
            lines.append("- Dislikes / avoid: \(profile.dislikedIngredients.joined(separator: ", "))")
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

        if !profile.diets.isEmpty || !profile.allergens.isEmpty {
            lines.append("")
            lines.append("HARD DIETARY RULES — NON-NEGOTIABLE. EVERY recipe you return MUST fully comply. If an ingredient would break a rule, do not use it; if a dish cannot be made compliant, do not suggest it at all:")
            for diet in profile.diets.sorted(by: { $0.title < $1.title }) {
                lines.append("- \(diet.hardRule)")
            }
            if !profile.allergens.isEmpty {
                lines.append("- ALLERGEN SAFETY: every recipe must be completely free of \(profile.allergens.joined(separator: ", ")) — including hidden sources, sauces, garnishes, stocks and cross-ingredients. Treat this as a health-and-safety requirement.")
            }
        }

        lines.append("")
        lines.append("RULES:")
        lines.append("- Prioritise recipes that use the most on-hand ingredients and the fewest new purchases.")
        if !profile.diets.isEmpty || !profile.allergens.isEmpty {
            lines.append("- The HARD DIETARY RULES and allergen safety above are absolute — obey them in every recipe, with no exceptions.")
        }
        lines.append("- Keep cook time at or under the max where possible; if not, keep it close.")
        lines.append("- Every ingredient MUST have a specific amount scaled to the servings (e.g. \"2 cups\", \"1 lb\", \"3 cloves\", \"to taste\").")
        lines.append("- Set haveIt=true for ingredients in the ON HAND list (and common staples: salt, pepper, oil, water, basic dried spices); otherwise haveIt=false. Keep haveIt=false items to at most 4 common extras.")
        lines.append("- Include 'servings', 'prepMinutes' and 'cookMinutes'.")
        lines.append("- Steps must be detailed, numbered and beginner-friendly: give temperatures, times, pan sizes and doneness cues (e.g. \"until golden\", \"until it reaches 165°F / 74°C\").")
        if !profile.equipment.isEmpty {
            lines.append("- IMPORTANT — write the steps for THIS cook's equipment, naming their appliances with exact settings and times. Examples: \"In your rice cooker, add 1 cup rice + 1½ cups water and cook until it switches to warm (~20 min)\"; \"Air-fry at 400°F/205°C for 12 min, shaking halfway\". If a component needs pre-cooking (rice, pasta, roasted veg), include that as its own step using their gear.")
        } else {
            lines.append("- Assume only a basic stovetop and oven; keep methods simple and clearly explained.")
        }
        lines.append("- Provide 2-4 short, practical 'tips' — make-ahead notes, easy swaps for the buy-list items, storage, or a way to level it up.")
        lines.append("- 'matchScore' is an integer 0-100 reflecting fit to pantry AND taste.")
        lines.append("- 'whyYoullLikeIt' is one short sentence referencing the cook's taste.")
        lines.append("- 'nutrition' is a rough PER-SERVING estimate: integer calories plus protein, carbs and fat in grams.")
        lines.append("")
        lines.append("- 'timeline' is a back-timed cooking schedule: for EACH key task, give how many minutes BEFORE serving to start it, so that ALL components (main, sides, sauces) finish together at the same moment. Include long-lead tasks (marinate, smoke, preheat, thaw, rest) with larger values and account for prep. The app sorts them, so order doesn't matter.")
        lines.append("Respond with ONLY a JSON object of this exact shape, no markdown:")
        lines.append("""
        {
          "recipes": [
            {
              "title": "string",
              "summary": "one-sentence description",
              "mealType": "breakfast|lunch|dinner|snack|dessert",
              "servings": 2,
              "prepMinutes": 10,
              "cookMinutes": 20,
              "ingredients": [
                { "name": "rice", "amount": "1 cup (2 cups cooked)", "haveIt": true },
                { "name": "soy sauce", "amount": "2 tbsp", "haveIt": false }
              ],
              "steps": ["Detailed step 1 (with appliance, temp, time)", "step 2", ...],
              "tips": ["short practical tip", "another tip"],
              "difficulty": "easy|medium|involved",
              "tags": ["tag", ...],
              "matchScore": 0,
              "whyYoullLikeIt": "string",
              "timeline": [
                { "task": "Sear the steak, then rest", "minutesBeforeServing": 15 },
                { "task": "Start the grits", "minutesBeforeServing": 30 },
                { "task": "Roast the asparagus", "minutesBeforeServing": 20 }
              ],
              "nutrition": { "calories": 520, "protein": 32, "carbs": 45, "fat": 22 }
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

    /// Decode a `{"items": [...]}` (or legacy `{"ingredients": [...]}`) string
    /// list from a vision response, trimming and de-duplicating.
    static func decodeStringList(from text: String) throws -> [String] {
        struct Payload: Decodable { var items: [String]?; var ingredients: [String]? }
        let json = sanitizedJSON(text)
        guard let data = json.data(using: .utf8) else {
            throw RecipeServiceError.decoding("not utf8")
        }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            var seen = Set<String>()
            var result: [String] = []
            for raw in (payload.items ?? payload.ingredients ?? []) {
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
        var servings: Int?
        var prepMinutes: Int?
        var cookMinutes: Int?
        var ingredients: [Ing]?
        var steps: [String]?
        var tips: [String]?
        var difficulty: String?
        var tags: [String]?
        var matchScore: Int?
        var whyYoullLikeIt: String?
        var timeline: [TL]?
        var nutrition: Nutri?
        // Legacy fields tolerated in case the model omits `ingredients`.
        var usesOnHand: [String]?
        var needsToBuy: [String]?

        struct Ing: Decodable {
            var name: String
            var amount: String?
            var haveIt: Bool?
        }

        struct TL: Decodable {
            var task: String
            var minutesBeforeServing: Int?
        }

        struct Nutri: Decodable {
            var calories: Int?
            var protein: Int?
            var carbs: Int?
            var fat: Int?
        }

        func toRecipe() -> Recipe {
            let ings: [RecipeIngredient]
            if let list = ingredients, !list.isEmpty {
                ings = list.map { RecipeIngredient(name: $0.name, amount: $0.amount ?? "", haveIt: $0.haveIt ?? false) }
            } else {
                ings = (usesOnHand ?? []).map { RecipeIngredient(name: $0, amount: "", haveIt: true) }
                     + (needsToBuy ?? []).map { RecipeIngredient(name: $0, amount: "", haveIt: false) }
            }
            return Recipe(
                title: title,
                summary: summary ?? "",
                mealType: MealType(rawValue: (mealType ?? "dinner").lowercased()) ?? .dinner,
                ingredients: ings,
                steps: steps ?? [],
                tips: tips ?? [],
                servings: max(1, servings ?? 2),
                prepMinutes: max(0, prepMinutes ?? 0),
                cookMinutes: max(0, cookMinutes ?? 20),
                difficulty: Difficulty(rawValue: (difficulty ?? "easy").lowercased()) ?? .easy,
                tags: tags ?? [],
                matchScore: min(100, max(0, matchScore ?? 0)),
                whyYoullLikeIt: whyYoullLikeIt ?? "",
                timeline: (timeline ?? []).compactMap { t in
                    t.task.trimmingCharacters(in: .whitespaces).isEmpty
                        ? nil
                        : TimelineTask(task: t.task, minutesBeforeServing: max(0, t.minutesBeforeServing ?? 0))
                },
                nutrition: nutrition.map {
                    NutritionInfo(calories: max(0, $0.calories ?? 0),
                                  protein: max(0, $0.protein ?? 0),
                                  carbs: max(0, $0.carbs ?? 0),
                                  fat: max(0, $0.fat ?? 0))
                }.flatMap { $0.hasAny ? $0 : nil }
            )
        }
    }
}
