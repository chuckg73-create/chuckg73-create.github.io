import Foundation

/// Fetches a recipe web page and reduces it to text worth sending to the model:
/// any schema.org JSON-LD recipe blocks (the reliable, structured source most
/// recipe sites embed) plus the stripped visible text as a fallback. No HTML
/// parser dependency — regex is enough since the model tolerates noise.
enum WebRecipeFetcher {

    enum FetchError: LocalizedError {
        case badURL
        case notReachable(Int)
        case empty

        var errorDescription: String? {
            switch self {
            case .badURL: return "That doesn't look like a valid web address."
            case .notReachable(let code): return "Couldn't open that page (error \(code)). Check the link and try again."
            case .empty: return "That page didn't have any readable text."
            }
        }
    }

    /// Normalize user input into a URL (adds https:// if the scheme is missing).
    static func normalize(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        return URL(string: s)
    }

    /// A friendly source label from a URL host, e.g. "allrecipes.com".
    static func sourceLabel(for url: URL) -> String {
        (url.host ?? "").replacingOccurrences(of: "www.", with: "")
    }

    /// Fetch and reduce the page to model-ready text (capped).
    static func fetchReadableText(from url: URL, session: URLSession = .shared) async throws -> String {
        var request = URLRequest(url: url)
        // Some sites gate on a browser-ish UA.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.notReachable(-1) }
        guard (200..<300).contains(http.statusCode) else { throw FetchError.notReachable(http.statusCode) }

        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let text = reduce(html)
        guard !text.isEmpty else { throw FetchError.empty }
        return text
    }

    /// Pull JSON-LD blocks + stripped visible text, capped to a sane length.
    static func reduce(_ html: String, maxChars: Int = 16000) -> String {
        var parts: [String] = []

        // 1) schema.org JSON-LD (the good stuff — structured recipe data).
        let ldBlocks = matches(in: html,
                               pattern: "<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>")
        if !ldBlocks.isEmpty {
            parts.append("STRUCTURED DATA (schema.org JSON-LD):")
            parts.append(contentsOf: ldBlocks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }

        // 2) Visible text: drop script/style/head noise, strip tags, decode a few
        //    entities, collapse whitespace.
        var body = html
        body = remove(body, pattern: "<script[\\s\\S]*?</script>")
        body = remove(body, pattern: "<style[\\s\\S]*?</style>")
        body = remove(body, pattern: "<head[\\s\\S]*?</head>")
        body = remove(body, pattern: "<noscript[\\s\\S]*?</noscript>")
        body = remove(body, pattern: "<!--[\\s\\S]*?-->")
        body = replace(body, pattern: "<[^>]+>", with: " ")
        body = decodeEntities(body)
        body = replace(body, pattern: "[ \\t]+", with: " ")
        body = replace(body, pattern: "(\\s*\\n\\s*){2,}", with: "\n")
        body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            parts.append("PAGE TEXT:")
            parts.append(body)
        }

        let joined = parts.joined(separator: "\n")
        return String(joined.prefix(maxChars))
    }

    // MARK: - Regex helpers

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static func remove(_ text: String, pattern: String) -> String {
        replace(text, pattern: pattern, with: "")
    }

    private static func replace(_ text: String, pattern: String, with repl: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return re.stringByReplacingMatches(in: text, range: range, withTemplate: repl)
    }

    private static func decodeEntities(_ text: String) -> String {
        var s = text
        let map = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                   "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&frac12;": "½",
                   "&frac14;": "¼", "&frac34;": "¾", "&deg;": "°"]
        for (k, v) in map { s = s.replacingOccurrences(of: k, with: v) }
        return s
    }
}
