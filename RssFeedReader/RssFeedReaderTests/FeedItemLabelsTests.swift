@testable import RssFeedReader
import Foundation
import Testing

struct FeedItemLabelsTests {

    // MARK: - labelsフィールドのデフォルト値

    @Test func labelsDefaultsToEmptyArray() {
        let item = FeedItem()
        #expect(item.labels.isEmpty)
    }

    @Test func labelsCanBeSetToMultipleValues() {
        var item = FeedItem()
        item.labels = ["go", "backend", "AI"]
        #expect(item.labels.count == 3)
        #expect(item.labels.contains("go"))
        #expect(item.labels.contains("backend"))
        #expect(item.labels.contains("AI"))
    }

    @Test func existingFeedItemFieldsUnaffectedByLabelsAddition() {
        var item = FeedItem()
        item.title = "テスト記事"
        item.link = "https://example.com/article"
        item.labels = ["frontend"]

        #expect(item.title == "テスト記事")
        #expect(item.link == "https://example.com/article")
        #expect(item.labels == ["frontend"])
    }

    @Test func labelsCanBeReassigned() {
        var item = FeedItem()
        item.labels = ["go"]
        item.labels = ["go", "backend"]
        #expect(item.labels == ["go", "backend"])
    }
}
