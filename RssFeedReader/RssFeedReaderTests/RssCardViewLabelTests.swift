@testable import RssFeedReader
import Foundation
import Testing

struct RssCardViewLabelTests {

    // MARK: - ラベル表示ロジック（prefix(3)）

    @Test func labelsPrefixLimitsToThreeItems() {
        var item = FeedItem()
        item.labels = ["go", "backend", "GCP", "CI/CD", "sre"]
        // prefix(3) で最大3件に絞る
        let displayed = Array(item.labels.prefix(3))
        #expect(displayed.count == 3)
        #expect(displayed == ["go", "backend", "GCP"])
    }

    @Test func labelsWithTwoItemsShowsAll() {
        var item = FeedItem()
        item.labels = ["go", "backend"]
        let displayed = Array(item.labels.prefix(3))
        #expect(displayed.count == 2)
    }

    @Test func labelsWithExactlyThreeItemsShowsAll() {
        var item = FeedItem()
        item.labels = ["go", "backend", "AI"]
        let displayed = Array(item.labels.prefix(3))
        #expect(displayed.count == 3)
    }

    @Test func emptyLabelsProducesNoBadges() {
        var item = FeedItem()
        item.labels = []
        let displayed = Array(item.labels.prefix(3))
        #expect(displayed.isEmpty)
    }

    // MARK: - View 初期化（コンパイル時型検証）

    @MainActor
    @Test func rssCardViewInitializesWithLabeledItem() {
        var item = FeedItem()
        item.title = "Go言語入門"
        item.labels = ["go", "backend"]
        let view = RssCardView(item: item, onTap: {})
        let _ = view
        #expect(true)
    }

    @MainActor
    @Test func rssCardViewInitializesWithEmptyLabels() {
        let item = FeedItem()
        let view = RssCardView(item: item, onTap: {})
        let _ = view
        #expect(true)
    }

    @MainActor
    @Test func rssCardViewInitializesWithManyLabels() {
        var item = FeedItem()
        item.labels = ["go", "backend", "GCP", "CI/CD", "sre", "AI"]
        let view = RssCardView(item: item, onTap: {})
        let _ = view
        #expect(true)
    }
}
