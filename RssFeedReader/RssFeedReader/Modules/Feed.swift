import Foundation

struct Feed: Identifiable, Hashable {
    var id: String { url }
    let url: String
    let limit : Int?
    let pubDateLimitDay: Int?
}

extension Feed {
    /// pubDateLimitDay がある場合、表示対象の最古日時（これより古い記事は落とす）
    func pubDateCutoffDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let d = pubDateLimitDay else { return nil }
        // dが0なら「今日以降のみ」みたいな扱い。負数は無効扱いにするのが安全
        guard d >= 0 else { return nil }
        return calendar.date(byAdding: .day, value: -d, to: now)
    }
    
}
