import Foundation

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id: String { stableID }

    let stableID: String
    let title: String
    let link: String
    let feedName: String
    var viewedAt: Date
}
