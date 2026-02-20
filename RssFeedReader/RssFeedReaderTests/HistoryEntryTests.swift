@testable import RssFeedReader
import Foundation
import Testing

struct HistoryEntryTests {
    // MARK: - id プロパティ

    @Test func idReturnsStableID() {
        let entry = HistoryEntry(
            stableID: "https://example.com/article-1",
            title: "テスト記事",
            link: "https://example.com/article-1",
            feedName: "Example Feed",
            viewedAt: Date()
        )
        #expect(entry.id == "https://example.com/article-1")
    }

    // MARK: - Codable ラウンドトリップ

    @Test func codableRoundTrip() throws {
        let original = HistoryEntry(
            stableID: "stable-id-001",
            title: "記事タイトル",
            link: "https://example.com/1",
            feedName: "Zenn",
            viewedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryEntry.self, from: data)

        #expect(decoded.stableID == original.stableID)
        #expect(decoded.title == original.title)
        #expect(decoded.link == original.link)
        #expect(decoded.feedName == original.feedName)
        #expect(decoded.viewedAt == original.viewedAt)
    }

    // MARK: - Hashable

    @Test func hashableConformance() {
        let a = HistoryEntry(
            stableID: "id-1",
            title: "記事A",
            link: "https://example.com/a",
            feedName: "Feed",
            viewedAt: Date(timeIntervalSince1970: 0)
        )
        let b = HistoryEntry(
            stableID: "id-1",
            title: "記事A",
            link: "https://example.com/a",
            feedName: "Feed",
            viewedAt: Date(timeIntervalSince1970: 0)
        )
        let set: Set<HistoryEntry> = [a, b]
        #expect(set.count == 1)
    }

    // MARK: - フィールド検証

    @Test func allFieldsStoredCorrectly() {
        let viewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = HistoryEntry(
            stableID: "stable-123",
            title: "Swift 6 の新機能",
            link: "https://swift.org/blog/swift6",
            feedName: "Swift.org",
            viewedAt: viewedAt
        )

        #expect(entry.stableID == "stable-123")
        #expect(entry.title == "Swift 6 の新機能")
        #expect(entry.link == "https://swift.org/blog/swift6")
        #expect(entry.feedName == "Swift.org")
        #expect(entry.viewedAt == viewedAt)
    }
}
