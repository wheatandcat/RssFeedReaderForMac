@testable import RssFeedReader
import Foundation
import Testing

struct HistoryStoreRepositoryTests {
    // テスト用の独立した UserDefaults スイートを使用
    private func makeRepository() -> HistoryStoreRepository {
        let suiteName = "test.history-store.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return HistoryStoreRepository(defaults: defaults)
    }

    // MARK: - load()

    @Test func loadReturnsEmptyStoreWhenNothingSaved() {
        let repo = makeRepository()
        let store = repo.load()
        #expect(store.entries.isEmpty)
    }

    // MARK: - save() + load() ラウンドトリップ

    @Test func saveAndLoadRoundTrip() {
        let repo = makeRepository()
        var store = HistoryStore()
        store.entries = [
            HistoryEntry(
                stableID: "id-1",
                title: "記事タイトル",
                link: "https://example.com/1",
                feedName: "Zenn",
                viewedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ]

        repo.save(store)
        let loaded = repo.load()

        #expect(loaded.entries.count == 1)
        #expect(loaded.entries[0].stableID == "id-1")
        #expect(loaded.entries[0].title == "記事タイトル")
        #expect(loaded.entries[0].feedName == "Zenn")
    }

    @Test func saveEmptyStoreAndLoadReturnsEmpty() {
        let repo = makeRepository()
        let store = HistoryStore()

        repo.save(store)
        let loaded = repo.load()

        #expect(loaded.entries.isEmpty)
    }

    // MARK: - フェイルセーフ（デコード失敗）

    @Test func loadReturnsEmptyStoreWhenDataIsCorrupt() {
        let suiteName = "test.history-store.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("invalid json data".data(using: .utf8), forKey: "history-store.v1")

        let repo = HistoryStoreRepository(defaults: defaults)
        let store = repo.load()

        #expect(store.entries.isEmpty)
    }

    // MARK: - 複数エントリの保存

    @Test func saveAndLoadMultipleEntries() {
        let repo = makeRepository()
        var store = HistoryStore()
        store.entries = [
            HistoryEntry(stableID: "a", title: "A", link: "https://a.com", feedName: "FA", viewedAt: Date(timeIntervalSince1970: 1_000)),
            HistoryEntry(stableID: "b", title: "B", link: "https://b.com", feedName: "FB", viewedAt: Date(timeIntervalSince1970: 2_000)),
            HistoryEntry(stableID: "c", title: "C", link: "https://c.com", feedName: "FC", viewedAt: Date(timeIntervalSince1970: 3_000)),
        ]

        repo.save(store)
        let loaded = repo.load()

        #expect(loaded.entries.count == 3)
        #expect(loaded.entries.map(\.stableID) == ["a", "b", "c"])
    }
}
