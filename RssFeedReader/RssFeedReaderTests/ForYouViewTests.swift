import Foundation
@testable import RssFeedReader
import Testing

// ForYouView はSwiftUIビューのため直接ユニットテストは困難。
// ForYouRecommender を通じたおすすめロジックはForYouRecommenderTests でカバー済み。
// ここでは ForYouView が依存する ForYouRecommender との統合を検証する。

struct ForYouViewLogicTests {
    private let recommender = ForYouRecommender()

    // referenceDate: 2026-03-22
    private let referenceDate = Date(timeIntervalSince1970: 1_742_601_600)

    private var withinDate: Date {
        referenceDate.addingTimeInterval(-24 * 60 * 60) // 1日前
    }

    // MARK: - 空状態の判定

    @Test func emptyStateWhenNoHistory() {
        let result = recommender.recommend(
            allItems: [makeItem(link: "https://example.com/a", labels: ["go"])],
            historyStore: HistoryStore(),
            labelStore: LabelStore(),
            referenceDate: referenceDate
        )
        // 履歴なし → 頻度マップ空 → スコア0 → 空配列
        #expect(result.isEmpty)
    }

    @Test func emptyStateWhenAllItemsViewed() {
        var historyStore = HistoryStore()
        historyStore.entries = [
            HistoryEntry(stableID: "h1", title: "記事A", link: "https://example.com/a", feedName: "Feed", viewedAt: withinDate),
        ]
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/a"] = ArticleLabel(url: "https://example.com/a", labels: ["go"], labeledAt: referenceDate)

        let result = recommender.recommend(
            allItems: [makeItem(link: "https://example.com/a", labels: ["go"])],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )
        // 閲覧済みのみ → 空配列
        #expect(result.isEmpty)
    }

    // MARK: - おすすめ表示

    @Test func recommendedItemsAreReturnedForMatchingLabels() {
        var historyStore = HistoryStore()
        historyStore.entries = [
            HistoryEntry(stableID: "h1", title: "閲覧済み", link: "https://example.com/viewed", feedName: "Feed", viewedAt: withinDate),
        ]
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/viewed"] = ArticleLabel(url: "https://example.com/viewed", labels: ["go"], labeledAt: referenceDate)
        labelStore.labelsByURL["https://example.com/new"] = ArticleLabel(url: "https://example.com/new", labels: ["go"], labeledAt: referenceDate)

        let newItem = makeItem(link: "https://example.com/new", labels: ["go"])

        let result = recommender.recommend(
            allItems: [newItem, makeItem(link: "https://example.com/viewed", labels: ["go"])],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )
        // 未閲覧かつラベル一致 → 1件返る
        #expect(result.count == 1)
        #expect(result[0].item.link == "https://example.com/new")
    }

    @Test func noRecommendationWhenLabelsDontMatch() {
        var historyStore = HistoryStore()
        historyStore.entries = [
            HistoryEntry(stableID: "h1", title: "閲覧済み", link: "https://example.com/viewed", feedName: "Feed", viewedAt: withinDate),
        ]
        var labelStore = LabelStore()
        labelStore.labelsByURL["https://example.com/viewed"] = ArticleLabel(url: "https://example.com/viewed", labels: ["go"], labeledAt: referenceDate)

        // 未閲覧記事のラベルが "frontend" のみ（頻度マップにない）
        let result = recommender.recommend(
            allItems: [makeItem(link: "https://example.com/new", labels: ["frontend"])],
            historyStore: historyStore,
            labelStore: labelStore,
            referenceDate: referenceDate
        )
        #expect(result.isEmpty)
    }

    // MARK: - ヘルパー

    private func makeItem(link: String, labels: [String] = []) -> FeedItem {
        var item = FeedItem()
        item.link = link
        item.labels = labels
        return item
    }
}
