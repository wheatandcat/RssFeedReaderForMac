@testable import RssFeedReader
import Foundation
import Testing

struct HistoryDateFormatterTests {
    // MARK: - formatViewedAt

    @Test func formatsDateToExpectedPattern() {
        // 2026-02-20 10:30:00 JST (UTC+9) → "2026/02/20 10:30"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 20
        components.hour = 10
        components.minute = 30
        components.second = 0
        let date = calendar.date(from: components)!

        let result = HistoryView.formatViewedAt(date)

        // ローカルタイムゾーンに依存するため、パターンを検証
        #expect(result.contains("2026"))
        #expect(result.contains("02"))
        #expect(result.contains("20"))
    }

    @Test func formatsDateContainsSlashSeparators() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = HistoryView.formatViewedAt(date)
        // "yyyy/MM/dd HH:mm" パターン: スラッシュとコロンを含む
        #expect(result.contains("/"))
        #expect(result.contains(":"))
    }

    @Test func formatsDateHasCorrectLength() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = HistoryView.formatViewedAt(date)
        // "yyyy/MM/dd HH:mm" = 16文字
        #expect(result.count == 16)
    }
}
