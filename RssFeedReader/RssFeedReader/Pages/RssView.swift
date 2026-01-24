import SwiftUI

struct RssView: View {
    @Environment(\.openURL) private var openURL

    let feeds: [Feed]
    let items: [FeedItem]
    let reload: () async -> Void

    // 2列固定（必要なら adaptive に変える）
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(items) { item in
                        RssCardView(item: item) {
                            if let url = URL(string: item.link) {
                                openURL(url)
                            }
                        }
                    }
                }
            }
            Divider()
            VStack {
                Button("更新") {
                    Task { await reload() }
                }
            }.padding(.bottom, 8)
        }
        .task {
            await reload()
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        RssView(
            feeds: [
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
            ],
            items: [
                FeedItem(title: "Example News 1", link: "https://example.com/1", pubDate: Date(), thumbnailURL: nil, siteTitle: "iteeeeeeeewwwwwww"),
                FeedItem(title: "Example News 2", link: "https://example.com/2", pubDate: Date().addingTimeInterval(-86400), thumbnailURL: URL(string: "https://placehold.jp/50x50.png")),
                FeedItem(title: "Example News 3", link: "https://example.com/2", pubDate: Date().addingTimeInterval(-86400), thumbnailURL: URL(string: "https://placehold.jp/50x50.png")),
            ],
            reload: {}
        )
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
}
