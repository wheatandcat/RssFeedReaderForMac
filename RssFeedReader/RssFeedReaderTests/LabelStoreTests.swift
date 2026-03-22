@testable import RssFeedReader
import Foundation
import Testing

struct LabelStoreTests {

    // MARK: - LabelStore デフォルト値

    @Test func labelStoreDefaultsToEmptyDictionary() {
        let store = LabelStore()
        #expect(store.labelsByURL.isEmpty)
    }

    // MARK: - ArticleLabel 操作

    @Test func canAddArticleLabelToStore() {
        var store = LabelStore()
        let label = ArticleLabel(
            url: "https://example.com/article",
            labels: ["go", "backend"],
            labeledAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        store.labelsByURL[label.url] = label

        #expect(store.labelsByURL.count == 1)
        #expect(store.labelsByURL["https://example.com/article"] != nil)
    }

    @Test func articleLabelStoredLabelsAreAccessible() {
        let label = ArticleLabel(
            url: "https://example.com/article",
            labels: ["go", "backend", "AI"],
            labeledAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(label.labels.count == 3)
        #expect(label.labels.contains("go"))
        #expect(label.labels.contains("backend"))
        #expect(label.labels.contains("AI"))
    }

    @Test func samURLOverwritesPreviousLabel() {
        var store = LabelStore()
        let url = "https://example.com/article"
        let first = ArticleLabel(url: url, labels: ["go"], labeledAt: Date(timeIntervalSince1970: 1_000))
        let second = ArticleLabel(url: url, labels: ["go", "backend"], labeledAt: Date(timeIntervalSince1970: 2_000))

        store.labelsByURL[url] = first
        store.labelsByURL[url] = second

        #expect(store.labelsByURL[url]?.labels == ["go", "backend"])
    }

    // MARK: - Codable 準拠

    @Test func labelStoreIsEncodableAndDecodable() throws {
        var store = LabelStore()
        store.labelsByURL["https://example.com/1"] = ArticleLabel(
            url: "https://example.com/1",
            labels: ["frontend", "react"],
            labeledAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LabelStore.self, from: data)

        #expect(decoded.labelsByURL.count == 1)
        #expect(decoded.labelsByURL["https://example.com/1"]?.labels == ["frontend", "react"])
    }

    @Test func articleLabelIsEncodableAndDecodable() throws {
        let original = ArticleLabel(
            url: "https://example.com/article",
            labels: ["go", "sre"],
            labeledAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ArticleLabel.self, from: data)

        #expect(decoded.url == original.url)
        #expect(decoded.labels == original.labels)
        #expect(decoded.labeledAt.timeIntervalSince1970 == original.labeledAt.timeIntervalSince1970)
    }
}
