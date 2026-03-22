@testable import RssFeedReader
import Foundation
import Testing

// MockArticleContentFetcher, MockLabelingService は
// FeedViewModelLabelingTests.swift で定義済み

// MARK: - 呼び出し回数を記録するモック

final class CountingLabelingService: LabelingServiceProtocol {
    private(set) var callCount = 0
    private(set) var labeledURLs: [String] = []
    let labels: [String]

    init(labels: [String] = ["go"]) {
        self.labels = labels
    }

    func label(content: String) async throws -> [String] {
        callCount += 1
        return labels
    }
}

final class CountingContentFetcher: ArticleContentFetchable {
    private(set) var fetchedURLs: [String] = []

    func fetch(url: URL) async throws -> String {
        fetchedURLs.append(url.absoluteString)
        return "記事コンテンツ: \(url.absoluteString)"
    }
}

@MainActor
struct FeedViewModelSkipLabelingTests {

    private func makeLabelRepo(store: LabelStore? = nil) -> LabelStoreRepository {
        let defaults = UserDefaults(suiteName: "test.label.\(UUID().uuidString)")!
        let repo = LabelStoreRepository(defaults: defaults)
        if let store { repo.save(store) }
        return repo
    }

    private func makeHistoryRepo() -> HistoryStoreRepository {
        let defaults = UserDefaults(suiteName: "test.history.\(UUID().uuidString)")!
        return HistoryStoreRepository(defaults: defaults)
    }

    // MARK: - 既ラベリング済みスキップ（要件4.4）

    @Test func alreadyLabeledArticleIsNotRelabeled() async {
        // 事前に https://example.com/a をラベリング済みにしておく
        var existingStore = LabelStore()
        existingStore.labelsByURL["https://example.com/a"] = ArticleLabel(
            url: "https://example.com/a",
            labels: ["go"],
            labeledAt: Date(timeIntervalSince1970: 1_000)
        )
        let labelRepo = makeLabelRepo(store: existingStore)
        let labeler = CountingLabelingService(labels: ["backend"])
        let fetcher = CountingContentFetcher()

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: fetcher,
            labelingService: labeler
        )

        var item = FeedItem()
        item.link = "https://example.com/a"

        await vm.labelArticles([item])

        // ラベリングサービスが呼ばれていないこと
        #expect(labeler.callCount == 0)
        // 元のラベルが保持されていること
        #expect(vm.labelStore.labelsByURL["https://example.com/a"]?.labels == ["go"])
    }

    @Test func onlyUnlabeledArticlesAreLabeled() async {
        // a は既ラベリング済み、b は未ラベリング
        var existingStore = LabelStore()
        existingStore.labelsByURL["https://example.com/a"] = ArticleLabel(
            url: "https://example.com/a",
            labels: ["go"],
            labeledAt: Date(timeIntervalSince1970: 1_000)
        )
        let labelRepo = makeLabelRepo(store: existingStore)
        let labeler = CountingLabelingService(labels: ["frontend"])
        let fetcher = CountingContentFetcher()

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: fetcher,
            labelingService: labeler
        )

        var itemA = FeedItem()
        itemA.link = "https://example.com/a"
        var itemB = FeedItem()
        itemB.link = "https://example.com/b"

        await vm.labelArticles([itemA, itemB])

        // labeler は b だけに呼ばれる
        #expect(labeler.callCount == 1)
        // a のラベルは変わらない
        #expect(vm.labelStore.labelsByURL["https://example.com/a"]?.labels == ["go"])
        // b にはラベルが付与される
        #expect(vm.labelStore.labelsByURL["https://example.com/b"]?.labels == ["frontend"])
    }

    // MARK: - 並行処理（要件4.5）

    @Test func multipleUnlabeledArticlesAreAllLabeled() async {
        let labelRepo = makeLabelRepo()
        let labeler = CountingLabelingService(labels: ["go"])
        let fetcher = CountingContentFetcher()

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: fetcher,
            labelingService: labeler
        )

        let urls = ["https://a.com", "https://b.com", "https://c.com"]
        let items = urls.map { url -> FeedItem in
            var item = FeedItem()
            item.link = url
            return item
        }

        await vm.labelArticles(items)

        // 3件すべてラベリングされる
        #expect(labeler.callCount == 3)
        for url in urls {
            #expect(vm.labelStore.labelsByURL[url] != nil)
        }
    }

    // MARK: - エラー分離（1件失敗しても他を継続）（要件4.4, 4.5）

    @Test func failingArticleDoesNotBlockOtherArticles() async {
        let labelRepo = makeLabelRepo()

        // b だけエラー、a と c は成功するフェッチャー
        final class SelectiveErrorFetcher: ArticleContentFetchable {
            func fetch(url: URL) async throws -> String {
                if url.absoluteString == "https://b.com" {
                    throw ArticleContentFetcherError.httpError(statusCode: 404)
                }
                return "記事コンテンツ"
            }
        }

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: SelectiveErrorFetcher(),
            labelingService: MockLabelingService(labels: ["go"])
        )

        var itemA = FeedItem(); itemA.link = "https://a.com"
        var itemB = FeedItem(); itemB.link = "https://b.com"
        var itemC = FeedItem(); itemC.link = "https://c.com"

        await vm.labelArticles([itemA, itemB, itemC])

        // a と c はラベリング成功
        #expect(vm.labelStore.labelsByURL["https://a.com"] != nil)
        #expect(vm.labelStore.labelsByURL["https://c.com"] != nil)
        // b はエラーでスキップ（nilのまま）
        #expect(vm.labelStore.labelsByURL["https://b.com"] == nil)
    }

    // MARK: - 空リンクのスキップ

    @Test func itemWithEmptyLinkIsSkipped() async {
        let labelRepo = makeLabelRepo()
        let labeler = CountingLabelingService()

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: MockArticleContentFetcher(content: "content"),
            labelingService: labeler
        )

        let item = FeedItem() // link は "" がデフォルト

        await vm.labelArticles([item])

        #expect(labeler.callCount == 0)
        #expect(vm.labelStore.labelsByURL.isEmpty)
    }
}
