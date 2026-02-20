@testable import RssFeedReader
import Foundation
import Testing

struct ContentViewIntegrationTests {
    // tab 列挙型に .history ケースが存在することを確認
    @Test func tabEnumHasHistoryCase() {
        let historyTab = tab.history
        #expect(historyTab == tab.history)
        #expect(historyTab != tab.rss)
        #expect(historyTab != tab.config)
    }

    // tab 列挙型の全ケースが異なる値であることを確認
    @Test func tabEnumCasesAreDistinct() {
        let cases: [tab] = [.rss, .config, .history]
        let unique = Set(cases)
        #expect(unique.count == 3)
    }

    // ContentView が正常に構築されることを確認（コンパイル時型検証）
    @MainActor
    @Test func contentViewInitializes() {
        let view = ContentView()
        let _ = view
        #expect(true)
    }
}
