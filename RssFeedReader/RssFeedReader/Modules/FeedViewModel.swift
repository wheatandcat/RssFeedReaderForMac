import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var feeds: [Feed] = [
        Feed(url: "https://zenn.dev/feed", limit: nil),
        Feed(url: "https://techfeed.io/feeds/categories/all?userId=5d719074b7fe174f32c77338", limit: nil),
        Feed(url: "https://feeds.rebuild.fm/rebuildfm", limit: nil),
        Feed(url: "https://www.publickey1.jp/atom.xml", limit: nil),
        Feed(url: "https://jser.info/rss/", limit: nil),
        Feed(url: "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml", limit: nil),
    ]
    @Published var items: [FeedItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let parser = UnifiedFeedParser()

    /// RSSを取得してitemsに反映する
    func reload() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        var merged: [FeedItem] = []

        await withTaskGroup(of: [FeedItem].self) { group in
            for feed in feeds {
                let text = feed.url
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: trimmed) else { continue }

                group.addTask {
                    do {
                        let (data, response) = try await URLSession.shared.data(from: url)
                        if let http = response as? HTTPURLResponse {
                            print("status:", http.statusCode)
                            print("content-type:", http.value(forHTTPHeaderField: "Content-Type") ?? "nil")
                            print("content-encoding:", http.value(forHTTPHeaderField: "Content-Encoding") ?? "nil")
                        }

                        print("head-bytes:", data.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " "))
                        print("head-text:", String(decoding: data.prefix(200), as: UTF8.self))
                        let items = try await self.parser.parse(data: data)
                        return items
                    } catch {
                        // 1フィード失敗は無視（ログだけ）
                        print("RSS取得失敗:", trimmed, error)
                        return []
                    }
                }
            }

            for await result in group {
                merged.append(contentsOf: result)
            }
        }
        // 🔑 更新日時が新しい順にソート
        items = merged.sorted {
            switch ($0.pubDate, $1.pubDate) {
            case let (a?, b?): return a > b
            case (_?, nil):   return true
            case (nil, _?):   return false
            case (nil, nil):  return $0.title < $1.title
            }
        }
    }
}

