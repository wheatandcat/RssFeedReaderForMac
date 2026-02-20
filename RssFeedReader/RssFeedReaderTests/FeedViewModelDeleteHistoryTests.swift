@testable import RssFeedReader
import Foundation
import Testing

@MainActor
struct FeedViewModelDeleteHistoryTests {
    private func makeVM() -> (FeedViewModel, HistoryStoreRepository) {
        let suiteName = "test.delete-history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let repo = HistoryStoreRepository(defaults: defaults)
        let vm = FeedViewModel(historyRepo: repo)
        return (vm, repo)
    }

    private func makeItem(stableID: String, title: String = "記事") -> FeedItem {
        FeedItem(title: title, link: "https://example.com/\(stableID)", siteTitle: "Feed", stableID: stableID)
    }

    // MARK: - removeHistoryEntry

    @Test func removeEntryDeletesOnlyTargetEntry() {
        let (vm, _) = makeVM()
        let itemA = makeItem(stableID: "id-a")
        let itemB = makeItem(stableID: "id-b")
        let itemC = makeItem(stableID: "id-c")
        vm.recordHistory(itemA)
        vm.recordHistory(itemB)
        vm.recordHistory(itemC)
        #expect(vm.historyEntries.count == 3)

        let entryB = vm.historyEntries.first(where: { $0.stableID == "id-b" })!
        vm.removeHistoryEntry(entryB)

        #expect(vm.historyEntries.count == 2)
        #expect(!vm.historyEntries.contains(where: { $0.stableID == "id-b" }))
        #expect(vm.historyEntries.contains(where: { $0.stableID == "id-a" }))
        #expect(vm.historyEntries.contains(where: { $0.stableID == "id-c" }))
    }

    @Test func removeEntryPersistsToRepository() {
        let (vm, repo) = makeVM()
        let item = makeItem(stableID: "id-1")
        vm.recordHistory(item)

        let entry = vm.historyEntries[0]
        vm.removeHistoryEntry(entry)

        let loaded = repo.load()
        #expect(loaded.entries.isEmpty)
    }

    @Test func removeNonExistentEntryDoesNotCrash() {
        let (vm, _) = makeVM()
        let ghost = HistoryEntry(
            stableID: "ghost-id",
            title: "存在しない",
            link: "https://ghost.com",
            feedName: "Ghost",
            viewedAt: Date()
        )
        // クラッシュしないことを確認
        vm.removeHistoryEntry(ghost)
        #expect(vm.historyEntries.isEmpty)
    }

    // MARK: - clearHistory

    @Test func clearHistoryRemovesAllEntries() {
        let (vm, _) = makeVM()
        vm.recordHistory(makeItem(stableID: "id-1"))
        vm.recordHistory(makeItem(stableID: "id-2"))
        vm.recordHistory(makeItem(stableID: "id-3"))
        #expect(vm.historyEntries.count == 3)

        vm.clearHistory()

        #expect(vm.historyEntries.isEmpty)
    }

    @Test func clearHistoryPersistsEmptyStoreToRepository() {
        let (vm, repo) = makeVM()
        vm.recordHistory(makeItem(stableID: "id-1"))
        vm.recordHistory(makeItem(stableID: "id-2"))

        vm.clearHistory()

        let loaded = repo.load()
        #expect(loaded.entries.isEmpty)
    }
}
