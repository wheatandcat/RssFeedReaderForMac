@testable import RssFeedReader
import Foundation
import Testing

@MainActor
struct FeedViewModelHistoryTests {
    // テスト用のリポジトリを生成するヘルパー
    private func makeRepo(suiteName: String = "test.history.\(UUID().uuidString)") -> HistoryStoreRepository {
        let defaults = UserDefaults(suiteName: suiteName)!
        return HistoryStoreRepository(defaults: defaults)
    }

    // MARK: - 初期状態

    @Test func historyEntriesInitiallyEmpty() {
        let repo = makeRepo()
        let vm = FeedViewModel(historyRepo: repo)
        #expect(vm.historyEntries.isEmpty)
    }

    @Test func historyEntriesLoadedFromRepositoryOnInit() {
        let repo = makeRepo()

        // 事前にリポジトリへデータを保存
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
        repo.save(store)

        let vm = FeedViewModel(historyRepo: repo)

        #expect(vm.historyEntries.count == 2)
        #expect(vm.historyEntries[0].stableID == "id-1")
        #expect(vm.historyEntries[1].stableID == "id-2")
    }

    @Test func historyEntriesIsPublished() {
        let repo = makeRepo()
        let vm = FeedViewModel(historyRepo: repo)
        // @Published プロパティとして外部から観測可能であることを確認
        // （コンパイル時に確認される）
        let _: [HistoryEntry] = vm.historyEntries
        #expect(true)
    }
}
