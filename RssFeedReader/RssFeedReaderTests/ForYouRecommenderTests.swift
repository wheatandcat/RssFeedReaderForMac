import Foundation
@testable import RssFeedReader
import Testing

struct ForYouRecommenderTests {
    let recommender = ForYouRecommender()

    // 基準日: 2026-03-22T00:00:00Z
    private let referenceDate = Date(timeIntervalSince1970: 1_742_601_600)

    // referenceDate の29日前（30日以内）
    private var withinDate: Date {
        referenceDate.addingTimeInterval(-29 * 24 * 60 * 60)
    }

    // referenceDate の31日前（30日超・対象外）
    private var outsideDate: Date {
        referenceDate.addingTimeInterval(-31 * 24 * 60 * 60)
    }

    // MARK: - 直近30日以内のエントリのみ使用

    @Test func onlyUsesHistoryEntriesWithin30Days() {
        // 30日以内: "go" ラベル, 30日超: "frontend" ラベル
        let historyStore = makeHistoryStore([
            ("https://old.com/article", outsideDate),
            ("https://recent.com/article", withinDate),
        ])
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://old.com/article"] = ArticleLabel(
            url: "https://old.com/article",
            labels: ["frontend"],
            labeledAt: referenceDate
        )
        labelStore.labelsByURL["https://recent.com/article"] = ArticleLabel(
            url: "https://recent.com/article",
            labels: ["go"],
            labeledAt: referenceDate
        )

        // "go" ラベルを持つ未閲覧記事 → スコアあり
        // "frontend" ラベルを持つ未閲覧記事 → 30日超のエントリは無視のためスコア0 → 除外
        var goItem = FeedItem()
        goItem.link = "https://new.com/go-article"
        goItem.labels = ["go"]

        var frontendItem = FeedItem()
        frontendItem.link = "https://new.com/frontend-article"
        frontendItem.labels = ["frontend"]

        let result = recommender.recommend(
            allItems: [goItem, frontendItem],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        let links = result.map(\.item.link)
        #expect(links.contains("https://new.com/go-article"))
        #expect(!links.contains("https://new.com/frontend-article"))
    }

    // MARK: - ラベル頻度マップの構築

    @Test func buildsLabelFrequencyMapCorrectly() {
        // "go" を2回、"backend" を1回 閲覧
        let historyStore = makeHistoryStore([
            ("https://example.com/a1", withinDate),
            ("https://example.com/a2", withinDate),
            ("https://example.com/a3", withinDate),
        ])
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/a1"] = ArticleLabel(url: "https://example.com/a1", labels: ["go"], labeledAt: referenceDate)
        labelStore.labelsByURL["https://example.com/a2"] = ArticleLabel(url: "https://example.com/a2", labels: ["go", "backend"], labeledAt: referenceDate)
        labelStore.labelsByURL["https://example.com/a3"] = ArticleLabel(url: "https://example.com/a3", labels: ["backend"], labeledAt: referenceDate)

        // "go" x2 + "backend" x2: goItem スコア=2, backendItem スコア=2
        // goAndBackendItem スコア=4 → 最高スコア
        var goItem = FeedItem()
        goItem.link = "https://new.com/go"
        goItem.labels = ["go"]

        var backendItem = FeedItem()
        backendItem.link = "https://new.com/backend"
        backendItem.labels = ["backend"]

        var goAndBackendItem = FeedItem()
        goAndBackendItem.link = "https://new.com/go-backend"
        goAndBackendItem.labels = ["go", "backend"]

        let result = recommender.recommend(
            allItems: [goItem, backendItem, goAndBackendItem],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        #expect(result.count == 3)
        #expect(result[0].item.link == "https://new.com/go-backend")
        #expect(result[0].score == 4)
        #expect(result[1].score == 2)
        #expect(result[2].score == 2)
    }

    // MARK: - スコアの正確な計算

    @Test func calculatesScoreCorrectly() {
        let historyStore = makeHistoryStore([
            ("https://example.com/a1", withinDate),
            ("https://example.com/a2", withinDate),
        ])
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/a1"] = ArticleLabel(url: "https://example.com/a1", labels: ["AI"], labeledAt: referenceDate)
        labelStore.labelsByURL["https://example.com/a2"] = ArticleLabel(url: "https://example.com/a2", labels: ["AI", "go"], labeledAt: referenceDate)

        // 頻度: AI=2, go=1
        // 記事ラベル ["AI", "go"] → スコア = 2 + 1 = 3
        var item = FeedItem()
        item.link = "https://new.com/ai-go"
        item.labels = ["AI", "go"]

        let result = recommender.recommend(
            allItems: [item],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        #expect(result.count == 1)
        #expect(result[0].score == 3)
    }

    // MARK: - スコア降順ソート

    @Test func sortsByScoreDescending() {
        let historyStore = makeHistoryStore([
            ("https://example.com/h1", withinDate),
            ("https://example.com/h2", withinDate),
            ("https://example.com/h3", withinDate),
        ])
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/h1"] = ArticleLabel(url: "https://example.com/h1", labels: ["go"], labeledAt: referenceDate)
        labelStore.labelsByURL["https://example.com/h2"] = ArticleLabel(url: "https://example.com/h2", labels: ["go"], labeledAt: referenceDate)
        labelStore.labelsByURL["https://example.com/h3"] = ArticleLabel(url: "https://example.com/h3", labels: ["AI"], labeledAt: referenceDate)

        // 頻度: go=2, AI=1
        var item1 = FeedItem()
        item1.link = "https://new.com/ai-only"
        item1.labels = ["AI"] // score=1

        var item2 = FeedItem()
        item2.link = "https://new.com/go-only"
        item2.labels = ["go"] // score=2

        var item3 = FeedItem()
        item3.link = "https://new.com/go-ai"
        item3.labels = ["go", "AI"] // score=3

        let result = recommender.recommend(
            allItems: [item1, item2, item3],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        #expect(result.count == 3)
        #expect(result[0].item.link == "https://new.com/go-ai")
        #expect(result[1].item.link == "https://new.com/go-only")
        #expect(result[2].item.link == "https://new.com/ai-only")
    }

    // MARK: - スコア1未満の記事を除外

    @Test func excludesItemsWithScoreLessThanOne() {
        let historyStore = makeHistoryStore([
            ("https://example.com/h1", withinDate),
        ])
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/h1"] = ArticleLabel(url: "https://example.com/h1", labels: ["go"], labeledAt: referenceDate)

        // "go" ラベルあり → スコア1
        var matchItem = FeedItem()
        matchItem.link = "https://new.com/go"
        matchItem.labels = ["go"]

        // "frontend" ラベルのみ → 頻度マップにないためスコア0
        var noMatchItem = FeedItem()
        noMatchItem.link = "https://new.com/frontend"
        noMatchItem.labels = ["frontend"]

        // ラベルなし → スコア0
        var noLabelItem = FeedItem()
        noLabelItem.link = "https://new.com/no-label"
        noLabelItem.labels = []

        let result = recommender.recommend(
            allItems: [matchItem, noMatchItem, noLabelItem],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        #expect(result.count == 1)
        #expect(result[0].item.link == "https://new.com/go")
        #expect(result[0].score == 1)
    }

    // MARK: - 閲覧済み記事を除外

    @Test func excludesAlreadyViewedItems() {
        let historyStore = makeHistoryStore([
            ("https://example.com/viewed", withinDate),
        ])
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/viewed"] = ArticleLabel(url: "https://example.com/viewed", labels: ["go"], labeledAt: referenceDate)

        // 閲覧済み記事
        var viewedItem = FeedItem()
        viewedItem.link = "https://example.com/viewed"
        viewedItem.labels = ["go"]

        // 未閲覧記事
        var newItem = FeedItem()
        newItem.link = "https://new.com/unviewed"
        newItem.labels = ["go"]

        let result = recommender.recommend(
            allItems: [viewedItem, newItem],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        let links = result.map(\.item.link)
        #expect(!links.contains("https://example.com/viewed"))
        #expect(links.contains("https://new.com/unviewed"))
    }

    // MARK: - 閲覧履歴なしの場合

    @Test func returnsEmptyWhenNoHistoryEntries() {
        let historyStore = HistoryStore()
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/a1"] = ArticleLabel(url: "https://example.com/a1", labels: ["go"], labeledAt: referenceDate)

        var item = FeedItem()
        item.link = "https://new.com/go"
        item.labels = ["go"]

        let result = recommender.recommend(
            allItems: [item],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        #expect(result.isEmpty)
    }

    // MARK: - 全記事閲覧済みの場合

    @Test func returnsEmptyWhenAllItemsViewed() {
        let historyStore = makeHistoryStore([
            ("https://example.com/a1", withinDate),
        ])
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/a1"] = ArticleLabel(url: "https://example.com/a1", labels: ["go"], labeledAt: referenceDate)

        var item = FeedItem()
        item.link = "https://example.com/a1"
        item.labels = ["go"]

        let result = recommender.recommend(
            allItems: [item],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )

        #expect(result.isEmpty)
    }

    // MARK: - ヘルパー

    private func makeHistoryStore(_ entries: [(link: String, viewedAt: Date)]) -> HistoryStore {
        var store = HistoryStore()
        store.entries = entries.enumerated().map { idx, e in
            HistoryEntry(
                stableID: "id-\(idx)",
                title: "記事\(idx)",
                link: e.link,
                feedName: "Feed",
                viewedAt: e.viewedAt
            )
        }
        return store
    }
}
