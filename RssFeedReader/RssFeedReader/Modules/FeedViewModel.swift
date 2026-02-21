import Combine
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var feeds: [Feed] = [] {
        didSet {
            saveFeeds()
        }
    }

    @Published private(set) var itemsByFeedURL: [String: [FeedItem]] = [:]

    static let defaultFeeds: [Feed] = [
        Feed(
            url: "https://zenn.dev/feed",
            limit: nil,
            pubDateLimitDay: 14,
            show: true
        ),
        Feed(
            url: "https://techfeed.io/feeds/categories/all?userId=5d719074b7fe174f32c77338",
            limit: nil,
            pubDateLimitDay: 14,
            show: true
        ),
        Feed(
            url: "https://feeds.rebuild.fm/rebuildfm",
            limit: 5,
            pubDateLimitDay: 40,
            show: true
        ),
        Feed(
            url: "https://www.publickey1.jp/atom.xml",
            limit: nil,
            pubDateLimitDay: 20,
            show: true
        ),
        Feed(
            url: "https://jser.info/rss/",
            limit: nil,
            pubDateLimitDay: 30,
            show: true
        ),
        Feed(
            url: "https://qiita.com/popular-items/feed",
            limit: 10,
            pubDateLimitDay: 14,
            show: true
        ),
        // Feed(url: "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml", limit: 5),
    ]

    var items: [FeedItem] {
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

    @Published private(set) var historyEntries: [HistoryEntry] = []

    private let parser = UnifiedFeedParser()
    private let seenRepo = SeenStoreRepository()
    private var seenStore: SeenStore = .init()
    private let historyRepo: HistoryStoreRepository
    private var historyStore: HistoryStore = .init()

    private enum DefaultsKey {
        static let feeds = "feeds.v1"
    }

    private var cancellables = Set<AnyCancellable>()

    init(historyRepo: HistoryStoreRepository = HistoryStoreRepository()) {
        self.historyRepo = historyRepo
        historyStore = historyRepo.load()
        historyEntries = historyStore.entries

        loadFeeds()

        // 初回起動で空ならデフォルトを入れる
        if feeds.isEmpty {
            feeds = Self.defaultFeeds
        }
    }

    func loadFeeds() {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKey.feeds)
        else {
            feeds = []
            return
        }

        do {
            feeds = try JSONDecoder().decode([Feed].self, from: data)
        } catch {
            print("❌ Failed to load feeds:", error)
            feeds = []
        }
    }

    func saveFeeds() {
        do {
            let data = try JSONEncoder().encode(feeds)
            UserDefaults.standard.set(data, forKey: DefaultsKey.feeds)
        } catch {
            print("❌ Failed to save feeds:", error)
        }
    }

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

    func recordHistory(_ item: FeedItem, at date: Date = Date()) {
        let effectiveStableID = item.stableID.isEmpty ? item.link : item.stableID
        let feedName = item.siteTitle.isEmpty ? item.formatSiteTitleFallback() : item.siteTitle

        if let idx = historyStore.entries.firstIndex(where: { $0.stableID == effectiveStableID }) {
            // 既存エントリの viewedAt を更新して先頭へ移動
            historyStore.entries[idx].viewedAt = date
            let updated = historyStore.entries.remove(at: idx)
            historyStore.entries.insert(updated, at: 0)
        } else {
            // 新規エントリを先頭に挿入
            let entry = HistoryEntry(
                stableID: effectiveStableID,
                title: item.title,
                link: item.link,
                feedName: feedName,
                viewedAt: date
            )
            historyStore.entries.insert(entry, at: 0)
        }

        // 500件上限：超過分を末尾から削除
        if historyStore.entries.count > 500 {
            historyStore.entries = Array(historyStore.entries.prefix(500))
        }

        historyStore.lastUpdatedAt = date
        historyEntries = historyStore.entries
        historyRepo.save(historyStore)
    }

    func removeHistoryEntry(_ entry: HistoryEntry) {
        historyStore.entries.removeAll { $0.stableID == entry.stableID }
        historyStore.lastUpdatedAt = Date()
        historyEntries = historyStore.entries
        historyRepo.save(historyStore)
    }

    func clearHistory() {
        historyStore = HistoryStore()
        historyEntries = []
        historyRepo.save(historyStore)
    }

    func reload() async {
        await reloadAll()
    }

    func reloadAll() async {
        seenStore = seenRepo.load()

        let now = Date()
        let calendar = Calendar.current
        var newDict: [String: [FeedItem]] = [:]

        await withTaskGroup(of: (String, [FeedItem]).self) { group in
            for feed in feeds {
                group.addTask {
                    if feed.show == false { return (feed.url, []) }

                    let urlText = feed.url.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let url = URL(string: urlText) else { return (feed.url, []) }

                    do {
                        let (data, response) = try await URLSession.shared.data(from: url)
                        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                            return (feed.url, [])
                        }

                        var items = try await self.parser.parse(data: data)

                        // sourceFeedURL を入れる
                        for i in items.indices {
                            items[i].sourceFeedURL = feed.url
                            if items[i].stableID.isEmpty {
                                items[i].stableID = items[i].link
                            }
                        }

                        let seenSet = await self.seenStore.seenIDsByFeedURL[feed.url] ?? []
                        for i in items.indices {
                            items[i].isNew = !seenSet.contains(items[i].stableID)
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

        // “今回表示した分” を既表示IDに追加して保存
        for (feedURL, items) in newDict {
            var set = seenStore.seenIDsByFeedURL[feedURL] ?? []
            for item in items {
                set.insert(item.stableID)
            }
            seenStore.seenIDsByFeedURL[feedURL] = set
        }
        seenStore.lastUpdatedAt = Date()
        seenRepo.save(seenStore)
    }
}
