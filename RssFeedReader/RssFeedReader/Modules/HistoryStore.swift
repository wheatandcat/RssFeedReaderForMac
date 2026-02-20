import Foundation

struct HistoryStore: Codable {
    var entries: [HistoryEntry] = []
    var lastUpdatedAt: Date = .init()
}
