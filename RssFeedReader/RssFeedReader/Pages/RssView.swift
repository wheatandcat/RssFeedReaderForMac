import SwiftUI

struct RssView: View {
    @Environment(\.openURL) private var openURL

    let items: [FeedItem]
    let reload: () async -> Void

    // 2列固定（必要なら adaptive に変える）
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 12) {

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
                .padding(16)
            }
            Button("更新") {
                Task { await reload() }
            }
        }
        .task {
            await reload()
        }
    }
}


#Preview {
    RssView(
        items: [
            FeedItem(title: "Example News 1", link: "https://example.com/1", pubDate: Date(), thumbnailURL: nil, siteTitle: "iteeeeeeeewwwwwww"),
            FeedItem(title: "Example News 2", link: "https://example.com/2", pubDate: Date().addingTimeInterval(-86400), thumbnailURL: URL(string: "https://placehold.jp/50x50.png")),
            FeedItem(title: "Example News 3", link: "https://example.com/2", pubDate: Date().addingTimeInterval(-86400), thumbnailURL: URL(string: "https://placehold.jp/50x50.png"))
        ],
        reload: {}
    )
}
