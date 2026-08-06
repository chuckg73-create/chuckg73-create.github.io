import Foundation

/// A shareable taste "card" — a person's name + taste profile — exchanged by QR
/// or link so a household can cook meals everyone will love. On-device only: no
/// accounts, nothing leaves the phone until the owner shows the code.
struct TasteCard: Codable, Hashable {
    var version: Int = 1
    var name: String
    var profile: TasteProfile

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case name = "n"
        case profile = "p"
    }
}

extension TasteCard {
    /// Compact base64url(JSON) payload carried inside the QR / link.
    var payload: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64URLEncodedString()
    }

    /// A `kindredkitchen://taste?c=…` deep link — scannable, AirDrop-able, and
    /// shareable in Messages. Opening it on another phone imports the card.
    var shareURL: URL? {
        guard let payload else { return nil }
        var c = URLComponents()
        c.scheme = "kindredkitchen"
        c.host = "taste"
        c.queryItems = [URLQueryItem(name: "c", value: payload)]
        return c.url
    }

    init?(payload: String) {
        guard let data = Data(base64URLEncoded: payload),
              let card = try? JSONDecoder().decode(TasteCard.self, from: data) else { return nil }
        self = card
    }

    /// Parse a scanned string or opened URL — accepts the full deep link or a
    /// bare payload.
    static func parse(_ string: String) -> TasteCard? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme == "kindredkitchen",
           let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let code = items.first(where: { $0.name == "c" })?.value {
            return TasteCard(payload: code)
        }
        return TasteCard(payload: trimmed)
    }

    static func parse(url: URL) -> TasteCard? { parse(url.absoluteString) }
}

// MARK: - base64url helpers

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var b = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        self.init(base64Encoded: b)
    }
}
