import Foundation

struct TechniqueGuide: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var difficulty: String
    var timeEstimate: String
    var intro: String
    var steps: [String]
    var tips: [String]
    var youtubeQuery: String

    private enum CodingKeys: String, CodingKey {
        case title, difficulty, timeEstimate, intro, steps, tips, youtubeQuery
    }
}
