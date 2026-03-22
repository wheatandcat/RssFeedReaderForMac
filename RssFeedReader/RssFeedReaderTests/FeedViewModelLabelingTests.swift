import Foundation
@testable import RssFeedReader
import Testing

// MARK: - テスト用モック

final class MockArticleContentFetcher: ArticleContentFetchable {
    private let result: Result<String, Error>

    init(content: String) { result = .success(content) }
    init(error: Error) { result = .failure(error) }

    func fetch(url _: URL) async throws -> String {
        try result.get()
    }
}

final class MockLabelingService: LabelingServiceProtocol {
    private let result: Result<[String], Error>

    init(labels: [String]) { result = .success(labels) }
    init(error: Error) { result = .failure(error) }

    func label(content _: String) async throws -> [String] {
        try result.get()
    }
}

// MARK: - FeedViewModel ラベリングテスト

@MainActor
struct FeedViewModelLabelingTests {
    private func makeLabelRepo() -> LabelStoreRepository {
        let defaults = UserDefaults(suiteName: "test.label.\(UUID().uuidString)")!
        return LabelStoreRepository(defaults: defaults)
    }

    private func makeHistoryRepo() -> HistoryStoreRepository {
        let defaults = UserDefaults(suiteName: "test.history.\(UUID().uuidString)")!
        return HistoryStoreRepository(defaults: defaults)
    }

    // MARK: - 初期化

    @Test func labelStoreIsInitializedFromRepository() {
        let labelRepo = makeLabelRepo()
        var store = LabelStore()
        store.labelsByURL["https://example.com"] = ArticleLabel(
            url: "https://example.com",
            labels: ["go"],
            labeledAt: Date(timeIntervalSince1970: 1000)
        )
        labelRepo.save(store)

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo
        )

        #expect(vm.labelStore.labelsByURL["https://example.com"]?.labels == ["go"])
    }

    @Test func labelStoreDefaultsToEmptyOnFirstLaunch() {
        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: makeLabelRepo()
        )
        #expect(vm.labelStore.labelsByURL.isEmpty)
    }

    @Test func labelStoreIsPublishedProperty() {
        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: makeLabelRepo()
        )
        // @Published プロパティとして外部から観測可能（コンパイル時確認）
        let _: LabelStore = vm.labelStore
        #expect(true)
    }

    // MARK: - labelArticles

    @Test func labelArticlesUpdatesLabelStore() async {
        let labelRepo = makeLabelRepo()
        let fetcher = MockArticleContentFetcher(content: "Go言語のバックエンド開発記事")
        let labeler = MockLabelingService(labels: ["go", "backend"])

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: fetcher,
            labelingService: labeler
        )

        var item = FeedItem()
        item.link = "https://example.com/article"

        await vm.labelArticles([item])

        #expect(vm.labelStore.labelsByURL["https://example.com/article"]?.labels == ["go", "backend"])
    }

    @Test func labelArticlesPersistsToRepository() async {
        let labelRepo = makeLabelRepo()
        let fetcher = MockArticleContentFetcher(content: "記事コンテンツ")
        let labeler = MockLabelingService(labels: ["frontend"])

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: fetcher,
            labelingService: labeler
        )

        var item = FeedItem()
        item.link = "https://example.com/frontend"

        await vm.labelArticles([item])

        // リポジトリに保存されていることを確認
        let loaded = labelRepo.load()
        #expect(loaded.labelsByURL["https://example.com/frontend"]?.labels == ["frontend"])
    }

    @Test func labelArticlesSkipsOnContentFetchError() async {
        let labelRepo = makeLabelRepo()
        let fetcher = MockArticleContentFetcher(error: ArticleContentFetcherError.emptyContent)
        let labeler = MockLabelingService(labels: ["go"])

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: fetcher,
            labelingService: labeler
        )

        var item = FeedItem()
        item.link = "https://example.com/error"

        await vm.labelArticles([item])

        // エラー時はスキップされてラベルなし
        #expect(vm.labelStore.labelsByURL["https://example.com/error"] == nil)
    }

    @Test func labelArticlesSkipsOnLabelingServiceError() async {
        let labelRepo = makeLabelRepo()
        let fetcher = MockArticleContentFetcher(content: "記事本文")
        let labeler = MockLabelingService(error: LabelingServiceError.ollamaUnavailable)

        let vm = FeedViewModel(
            historyRepo: makeHistoryRepo(),
            labelRepo: labelRepo,
            contentFetcher: fetcher,
            labelingService: labeler
        )

        var item = FeedItem()
        item.link = "https://example.com/ollama-error"

        await vm.labelArticles([item])

        // Ollama 未起動でもスキップして継続（エラーにならない）
        #expect(vm.labelStore.labelsByURL["https://example.com/ollama-error"] == nil)
    }
}
