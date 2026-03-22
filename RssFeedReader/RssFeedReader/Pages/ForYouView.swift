import Charts
import SwiftUI

struct LabelFrequencyEntry: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

struct ForYouView: View {
    @Environment(\.openURL) private var openURL

    let allItems: [FeedItem]
    let historyStore: HistoryStore
    let labelStore: LabelStore
    let onOpen: (FeedItem) -> Void

    private let recommender = ForYouRecommender()

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private var recommendedItems: [FeedItem] {
        recommender.recommend(
            allItems: allItems,
            historyStore: historyStore,
            labelStore: labelStore
        ).map(\.item)
    }

    /// 直近30日の閲覧履歴からラベル頻度を計算（上位8件）
    private var labelFrequencies: [LabelFrequencyEntry] {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let recentEntries = historyStore.entries.filter { $0.viewedAt >= thirtyDaysAgo }

        var freq: [String: Int] = [:]
        for entry in recentEntries {
            guard let articleLabel = labelStore.labelsByURL[entry.link] else { continue }
            for label in articleLabel.labels {
                freq[label, default: 0] += 1
            }
        }

        return freq
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { LabelFrequencyEntry(label: $0.key, count: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !labelFrequencies.isEmpty {
                    labelChartSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }

                if recommendedItems.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(recommendedItems) { item in
                            RssCardView(item: item) {
                                if let url = URL(string: item.link) {
                                    openURL(url)
                                }
                                onOpen(item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var labelChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("あなたの興味（直近30日）")
                .font(.headline)

            HStack(alignment: .center, spacing: 32) {
                Chart(labelFrequencies) { entry in
                    SectorMark(
                        angle: .value("件数", entry.count),
                        innerRadius: .ratio(0.45),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("ラベル", entry.label))
                    .cornerRadius(5)
                }
                .chartLegend(.hidden)
                .frame(width: 280, height: 280)

                // 凡例
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(labelFrequencies.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .frame(width: 12, height: 12)
                                .foregroundStyle(colorForIndex(index))
                            Text(entry.label)
                                .font(.body)
                            Spacer()
                            Text("\(entry.count)件")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)

            Divider()
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer(minLength: 60)
            Text("おすすめ記事はまだありません。記事を読むと表示されます。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .yellow, .cyan, .mint]
        return colors[index % colors.count]
    }
}

#Preview("おすすめあり") {
    let historyStore: HistoryStore = {
        var store = HistoryStore()
        store.entries = [
            HistoryEntry(stableID: "h1", title: "Go言語入門", link: "https://example.com/go-intro", feedName: "Zenn", viewedAt: Date().addingTimeInterval(-86400)),
            HistoryEntry(stableID: "h2", title: "Reactの基礎", link: "https://example.com/react-intro", feedName: "Qiita", viewedAt: Date().addingTimeInterval(-172800)),
            HistoryEntry(stableID: "h3", title: "Rustで高速化", link: "https://example.com/rust", feedName: "Zenn", viewedAt: Date().addingTimeInterval(-259200)),
            HistoryEntry(stableID: "h4", title: "GoのWebフレームワーク", link: "https://example.com/go-web", feedName: "Zenn", viewedAt: Date().addingTimeInterval(-345600)),
        ]
        return store
    }()

    let labelStore: LabelStore = {
        var store = LabelStore()
        store.labelsByURL["https://example.com/go-intro"] = ArticleLabel(url: "https://example.com/go-intro", labels: ["go", "backend"], labeledAt: Date())
        store.labelsByURL["https://example.com/react-intro"] = ArticleLabel(url: "https://example.com/react-intro", labels: ["frontend", "react"], labeledAt: Date())
        store.labelsByURL["https://example.com/rust"] = ArticleLabel(url: "https://example.com/rust", labels: ["rust", "backend"], labeledAt: Date())
        store.labelsByURL["https://example.com/go-web"] = ArticleLabel(url: "https://example.com/go-web", labels: ["go", "web"], labeledAt: Date())
        store.labelsByURL["https://example.com/new-article"] = ArticleLabel(url: "https://example.com/new-article", labels: ["go"], labeledAt: Date())
        return store
    }()

    let items: [FeedItem] = [
        FeedItem(title: "Go 1.23 リリースノート", link: "https://example.com/new-article", pubDate: Date(), thumbnailURL: nil, siteTitle: "Go Blog"),
        FeedItem(title: "React 19 の新機能", link: "https://example.com/react-new", pubDate: Date(), thumbnailURL: nil, siteTitle: "React Blog"),
    ]

    ForYouView(allItems: items, historyStore: historyStore, labelStore: labelStore, onOpen: { _ in })
        .frame(width: 700, height: 600)
}

#Preview("空の状態") {
    ForYouView(allItems: [], historyStore: HistoryStore(), labelStore: LabelStore(), onOpen: { _ in })
        .frame(width: 700, height: 500)
}
