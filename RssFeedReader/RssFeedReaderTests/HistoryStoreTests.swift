@testable import RssFeedReader
import Foundation
import Testing

struct HistoryStoreTests {
    // MARK: - デフォルト値

    @Test func defaultInitializationHasEmptyEntries() {
        let store = HistoryStore()
        #expect(store.entries.isEmpty)
    }

    @Test func defaultInitializationHasRecentTimestamp() {
        let before = Date()
        let store = HistoryStore()
        let after = Date()
        #expect(store.lastUpdatedAt >= before)
        #expect(store.lastUpdatedAt <= after)
    }

    // MARK: - Codable ラウンドトリップ

    @Test func codableRoundTripWithEntries() throws {
        var store = HistoryStore()
        store.entries = [
            HistoryEntry(
                stableID: "id-1",
                title: "記事1",
                link: "https://example.com/1",
                feedName: "Feed A",
                viewedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            HistoryEntry(
                stableID: "id-2",
                title: "記事2",
                link: "https://example.com/2",
                feedName: "Feed B",
                viewedAt: Date(timeIntervalSince1970: 1_700_001_000)
            ),
        ]
        store.lastUpdatedAt = Date(timeIntervalSince1970: 1_700_002_000)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryStore.self, from: data)

        #expect(decoded.entries.count == 2)
        #expect(decoded.entries[0].stableID == "id-1")
        #expect(decoded.entries[1].stableID == "id-2")
        #expect(decoded.lastUpdatedAt == store.lastUpdatedAt)
    }

    @Test func codableRoundTripWithEmptyEntries() throws {
        let store = HistoryStore()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryStore.self, from: data)

        #expect(decoded.entries.isEmpty)
    }

    // MARK: - エントリの可変性

    @Test func entriesAreMutable() {
        var store = HistoryStore()
        let entry = HistoryEntry(
            stableID: "id-1",
            title: "記事",
            link: "https://example.com",
            feedName: "Feed",
            viewedAt: Date()
        )
        store.entries.append(entry)
        #expect(store.entries.count == 1)
    }
}
