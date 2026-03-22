import Foundation

struct ScoredItem {
    let item: FeedItem
    let score: Int
}

final class ForYouRecommender {

    /// 閲覧履歴ラベル頻度に基づき未閲覧記事をスコアリングして返す。
    ///
    /// - Parameters:
    ///   - allItems: 全フィード記事
    ///   - historyStore: 閲覧履歴ストア
    ///   - labelStore: ラベルストア
    ///   - referenceDate: 基準日（デフォルトは現在時刻）
    /// - Returns: スコア降順でソートされた `ScoredItem` 配列（スコア1以上のみ）
    func recommend(
        allItems: [FeedItem],
        historyStore: HistoryStore,
        labelStore: LabelStore,
        referenceDate: Date = Date()
    ) -> [ScoredItem] {
        // 1. 直近30日以内の閲覧エントリを抽出
        let thirtyDaysAgo = referenceDate.addingTimeInterval(-30 * 24 * 60 * 60)
        let recentEntries = historyStore.entries.filter { $0.viewedAt >= thirtyDaysAgo }

        // 2. ラベル頻度マップを構築
        var labelFrequency: [String: Int] = [:]
        for entry in recentEntries {
            guard let articleLabel = labelStore.labelsByURL[entry.link] else { continue }
            for label in articleLabel.labels {
                labelFrequency[label, default: 0] += 1
            }
        }

        // 3. 閲覧済みURLセットを構築
        let viewedURLs = Set(historyStore.entries.map(\.link))

        // 4. 未閲覧記事を抽出してスコアを計算
        let scored = allItems
            .filter { !viewedURLs.contains($0.link) }
            .compactMap { item -> ScoredItem? in
                let labels = labelStore.labelsByURL[item.link]?.labels ?? item.labels
                let score = labels.reduce(0) { acc, label in
                    acc + (labelFrequency[label] ?? 0)
                }
                guard score >= 1 else { return nil }
                return ScoredItem(item: item, score: score)
            }

        // 5. スコア降順でソート
        return scored.sorted { $0.score > $1.score }
    }
}
