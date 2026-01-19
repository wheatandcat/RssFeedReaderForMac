import SwiftUI

struct RssView: View {
    let items: [FeedItem]
    let reload: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            List {
                Section("記事一覧") {
                    ForEach(items) { item in
                        HStack {
                            if let url = item.thumbnailURL {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 40, height: 40)
                                .clipped()
                                .cornerRadius(5)
                            } else if let url = item.siteImageURL {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 40, height: 40)
                                .clipped()
                                .cornerRadius(5)
                            } else {
                                Text(item.siteTitle != "" ? item.siteTitle : "Unknown")
                                    .foregroundStyle(.secondary)
                                    .foregroundColor(.white)
                                    .padding(2)                // ← 文字と背景の間
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.9))
                                    .cornerRadius(5)
                            }

                            VStack(alignment: .leading) {
                                Text(item.title).font(.headline)
                                HStack {
                                    if let d = item.pubDate {
                                        Text(d.formatted())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("by \(item.siteTitle)")                               .font(.footnote)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            Button("更新") {
                Task { await reload() }
            }
        }
        .padding()
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
