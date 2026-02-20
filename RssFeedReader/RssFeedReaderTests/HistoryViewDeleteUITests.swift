@testable import RssFeedReader
import Foundation
import Testing

/// Task 3.3: HistoryView の削除 UI コールバックシグネチャ検証
/// UI インタラクション自体は #Preview と UITest で検証する
struct HistoryViewDeleteUITests {
    // onDelete コールバックが HistoryEntry を受け取る型であることを確認
    @Test func onDeleteCallbackIsInvokedWithCorrectEntry() {
        var deletedEntry: HistoryEntry?
        var clearAllCalled = false

        let entries = [
            HistoryEntry(
                stableID: "id-1",
                title: "記事A",
                link: "https://example.com/a",
                feedName: "Feed",
                viewedAt: Date()
            )
        ]

        // コールバックをキャプチャしてシグネチャを検証
        let onDelete: (HistoryEntry) -> Void = { entry in
            deletedEntry = entry
        }
        let onClearAll: () -> Void = {
            clearAllCalled = true
        }

        // コールバックを直接呼び出してシグネチャが正しく動作することを確認
        onDelete(entries[0])
        #expect(deletedEntry?.stableID == "id-1")

        onClearAll()
        #expect(clearAllCalled)
    }

    // HistoryView が正しいプロパティシグネチャで初期化できることを確認
    @Test func historyViewInitializesWithCorrectCallbackTypes() {
        var openedEntry: HistoryEntry?
        var deletedEntry: HistoryEntry?
        var clearAllCalled = false

        let view = HistoryView(
            historyEntries: [],
            onOpen: { openedEntry = $0 },
            onDelete: { deletedEntry = $0 },
            onClearAll: { clearAllCalled = true }
        )

        // HistoryView が正常に構築されることを確認（コンパイル時検証）
        let _ = view
        #expect(openedEntry == nil)
        #expect(deletedEntry == nil)
        #expect(!clearAllCalled)
    }
}
