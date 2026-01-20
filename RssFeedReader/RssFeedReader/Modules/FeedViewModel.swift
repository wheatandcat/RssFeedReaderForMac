import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var feeds: [Feed] = [
        Feed(
            url: "https://zenn.dev/feed",
            limit: nil,
            pubDateLimitDay: 14
        ),
        Feed(
            url: "https://techfeed.io/feeds/categories/all?userId=5d719074b7fe174f32c77338",
            limit: nil,
            pubDateLimitDay: 14
        ),
        Feed(
            url: "https://feeds.rebuild.fm/rebuildfm",
            limit: 5,
            pubDateLimitDay: 40
        ),
        Feed(
            url: "https://www.publickey1.jp/atom.xml",
            limit: nil,
            pubDateLimitDay: 20
        ),
        Feed(
            url: "https://jser.info/rss/",
            limit: nil,
            pubDateLimitDay: 30
        ),
        Feed(
            url: "https://qiita.com/popular-items/feed",
            limit: 10,
            pubDateLimitDay: 14
        )
        // Feed(url: "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml", limit: 5),
    ]
    @Published private(set) var itemsByFeedURL: [String: [FeedItem]] = [:]
    
    
    var items: [FeedItem] {
        itemsByFeedURL.values
            .flatMap { $0 }
            .sorted { a, b in
                switch (a.pubDate, b.pubDate) {
                case let (x?, y?): return x > y
                case (_?, nil):   return true
                case (nil, _?):   return false
                default:          return a.title < b.title
                }
            }
    }
    
    private let parser = UnifiedFeedParser()

    var mergedItems: [FeedItem] {
        itemsByFeedURL.values
            .flatMap { $0 }
            .sorted { a, b in
                switch (a.pubDate, b.pubDate) {
                case let (x?, y?): return x > y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.title < b.title
                }
            }
    }
    
    func reload() async {
        await reloadAll()
    }
    
    func reloadAll() async {
        let now = Date()
        let calendar = Calendar.current
        var newDict: [String: [FeedItem]] = [:]

        await withTaskGroup(of: (String, [FeedItem]).self) { group in
            for feed in feeds {
                group.addTask {
                    let urlText = feed.url.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let url = URL(string: urlText) else { return (feed.url, []) }

                    do {
                        let (data, response) = try await URLSession.shared.data(from: url)
                        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                            return (feed.url, [])
                        }

                        var items = try await self.parser.parse(data: data)

                        // sourceFeedURL を入れる
                        for i in items.indices {
                            items[i].sourceFeedURL = feed.url
                        }

                        if let cutoff = await feed.pubDateCutoffDate(now: now, calendar: calendar) {
                            items = items.filter { item in
                                // pubDateがない記事は落とすのが無難（残したいなら仕様を決める）
                                guard let d = item.pubDate else { return false }
                                return d >= cutoff
                            }
                        }

                        // 更新日でソート
                        items.sort { a, b in
                            switch (a.pubDate, b.pubDate) {
                            case let (x?, y?): return x > y
                            case (_?, nil): return true
                            case (nil, _?): return false
                            default: return a.title < b.title
                            }
                        }

                        // ★ limit 適用（表示件数のカスタマイズ）
                        if let limit = feed.limit, limit >= 0, items.count > limit {
                            items = Array(items.prefix(limit))
                        }

                        return (feed.url, items)
                    } catch {
                        return (feed.url, [])
                    }
                }
            }

            for await (feedURL, items) in group {
                newDict[feedURL] = items
            }
        }

        itemsByFeedURL = newDict
    }
}

