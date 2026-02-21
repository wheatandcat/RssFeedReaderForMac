@testable import RssFeedReader
import Foundation
import Testing

@MainActor
struct FeedViewModelRecordHistoryTests {
    private func makeVM() -> FeedViewModel {
        let suiteName = "test.record-history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let repo = HistoryStoreRepository(defaults: defaults)
        return FeedViewModel(historyRepo: repo)
    }

    private func makeItem(
        stableID: String = "id-1",
        title: String = "テスト記事",
        link: String = "https://example.com/1",
        siteTitle: String = "Example Feed"
    ) -> FeedItem {
        FeedItem(title: title, link: link, siteTitle: siteTitle, stableID: stableID)
    }

    // MARK: - 新規記録

    @Test func recordNewItemAddsToHistoryEntries() {
        let vm = makeVM()
        let item = makeItem()

        vm.recordHistory(item)

        #expect(vm.historyEntries.count == 1)
        #expect(vm.historyEntries[0].stableID == "id-1")
        #expect(vm.historyEntries[0].title == "テスト記事")
        #expect(vm.historyEntries[0].feedName == "Example Feed")
    }

    @Test func recordItemUsesLinkAsStableIDWhenEmpty() {
        let vm = makeVM()
        let item = makeItem(stableID: "", link: "https://example.com/fallback")

        vm.recordHistory(item)

        #expect(vm.historyEntries[0].stableID == "https://example.com/fallback")
    }

    @Test func recordItemUsesSiteTitleFallbackWhenSiteTitleEmpty() {
        let vm = makeVM()
        let item = makeItem(siteTitle: "", link: "https://example.com/article")

        vm.recordHistory(item)

        // siteTitle が空のとき、リンクのホスト名を使う
        #expect(vm.historyEntries[0].feedName == "example.com")
    }

    // MARK: - 重複記録（同一 stableID）

    @Test func recordSameItemTwiceDoesNotIncreaseCount() {
        let vm = makeVM()
        let item = makeItem(stableID: "id-dup")

        vm.recordHistory(item)
        vm.recordHistory(item)

        #expect(vm.historyEntries.count == 1)
    }

    @Test func recordSameItemUpdatesViewedAt() {
        let vm = makeVM()
        let item = makeItem(stableID: "id-time")

        vm.recordHistory(item)
        let firstViewedAt = vm.historyEntries[0].viewedAt

        // 少し待ってから再記録（日時が更新されることを確認）
        let laterDate = Date(timeIntervalSinceNow: 1)
        vm.recordHistory(item, at: laterDate)

        #expect(vm.historyEntries[0].viewedAt == laterDate)
        #expect(vm.historyEntries[0].viewedAt > firstViewedAt)
    }

    @Test func recordSameItemMovesItToFront() {
        let vm = makeVM()
        let itemA = makeItem(stableID: "id-a", title: "A")
        let itemB = makeItem(stableID: "id-b", title: "B")

        vm.recordHistory(itemA)
        vm.recordHistory(itemB)
        // この時点では B が先頭
        #expect(vm.historyEntries[0].stableID == "id-b")

        // A を再記録すると A が先頭に移動する
        vm.recordHistory(itemA)
        #expect(vm.historyEntries[0].stableID == "id-a")
        #expect(vm.historyEntries.count == 2)
    }

    // MARK: - 先頭への挿入順

    @Test func newItemsInsertedAtFront() {
        let vm = makeVM()
        let itemA = makeItem(stableID: "id-a", title: "A")
        let itemB = makeItem(stableID: "id-b", title: "B")

        vm.recordHistory(itemA)
        vm.recordHistory(itemB)

        #expect(vm.historyEntries[0].stableID == "id-b")
        #expect(vm.historyEntries[1].stableID == "id-a")
    }

    // MARK: - 500件上限

    @Test func recordBeyond500EntriesTrimsOldest() {
        let vm = makeVM()

        for i in 0 ..< 501 {
            let item = makeItem(stableID: "id-\(i)", title: "記事\(i)", link: "https://example.com/\(i)")
            vm.recordHistory(item)
        }

        #expect(vm.historyEntries.count == 500)
        // 最古（最初に記録した id-0）が削除されている
        #expect(!vm.historyEntries.contains(where: { $0.stableID == "id-0" }))
    }
}
