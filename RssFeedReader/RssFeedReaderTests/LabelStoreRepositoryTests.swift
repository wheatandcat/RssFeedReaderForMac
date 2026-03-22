import Foundation
@testable import RssFeedReader
import Testing

struct LabelStoreRepositoryTests {
    private func makeRepository() -> LabelStoreRepository {
        let suiteName = "test.label-store.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return LabelStoreRepository(defaults: defaults)
    }

    // MARK: - load()

    @Test func loadReturnsEmptyStoreWhenNothingSaved() {
        let repo = makeRepository()
        let store = repo.load()
        #expect(store.labelsByURL.isEmpty)
    }

    // MARK: - save() + load() ラウンドトリップ

    @Test func saveAndLoadRoundTrip() {
        let repo = makeRepository()
        var store = LabelStore()
        store.labelsByURL["https://example.com/article"] = ArticleLabel(
            url: "https://example.com/article",
            labels: ["go", "backend"],
            labeledAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        repo.save(store)
        let loaded = repo.load()

        #expect(loaded.labelsByURL.count == 1)
        #expect(loaded.labelsByURL["https://example.com/article"]?.labels == ["go", "backend"])
    }

    @Test func saveEmptyStoreAndLoadReturnsEmpty() {
        let repo = makeRepository()
        repo.save(LabelStore())
        let loaded = repo.load()
        #expect(loaded.labelsByURL.isEmpty)
    }

    @Test func saveAndLoadMultipleArticleLabels() {
        let repo = makeRepository()
        var store = LabelStore()
        store.labelsByURL["https://a.com"] = ArticleLabel(url: "https://a.com", labels: ["go"], labeledAt: Date(timeIntervalSince1970: 1000))
        store.labelsByURL["https://b.com"] = ArticleLabel(url: "https://b.com", labels: ["frontend", "react"], labeledAt: Date(timeIntervalSince1970: 2000))

        repo.save(store)
        let loaded = repo.load()

        #expect(loaded.labelsByURL.count == 2)
        #expect(loaded.labelsByURL["https://a.com"]?.labels == ["go"])
        #expect(loaded.labelsByURL["https://b.com"]?.labels == ["frontend", "react"])
    }

    // MARK: - 上書き更新

    @Test func saveOverwritesPreviousData() {
        let repo = makeRepository()
        var store = LabelStore()
        store.labelsByURL["https://example.com"] = ArticleLabel(url: "https://example.com", labels: ["go"], labeledAt: Date(timeIntervalSince1970: 1000))
        repo.save(store)

        var updated = LabelStore()
        updated.labelsByURL["https://example.com"] = ArticleLabel(url: "https://example.com", labels: ["go", "backend"], labeledAt: Date(timeIntervalSince1970: 2000))
        repo.save(updated)

        let loaded = repo.load()
        #expect(loaded.labelsByURL["https://example.com"]?.labels == ["go", "backend"])
    }

    // MARK: - フェイルセーフ（デコード失敗）

    @Test func loadReturnsEmptyStoreWhenDataIsCorrupt() {
        let suiteName = "test.label-store.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("invalid json".data(using: .utf8), forKey: "article-labels.v1")

        let repo = LabelStoreRepository(defaults: defaults)
        let store = repo.load()
        #expect(store.labelsByURL.isEmpty)
    }
}
