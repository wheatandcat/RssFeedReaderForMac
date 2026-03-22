import Foundation

struct ArticleLabel: Codable {
    let url: String
    var labels: [String]
    let labeledAt: Date
}

struct LabelStore: Codable {
    var labelsByURL: [String: ArticleLabel] = [:]
}
