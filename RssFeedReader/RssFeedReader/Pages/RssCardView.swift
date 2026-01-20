import SwiftUI

struct RssCardView: View {
    let item: FeedItem
    let onTap: () -> Void

    private let imageHeight: CGFloat = 170

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    siteIcon
                        .frame(width: 28, height: 28)
                        
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.siteTitle.isEmpty ? item.formatSiteTitleFallback() : item.siteTitle)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let d = item.pubDate {
                            Text(d.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                Text(item.title.isEmpty ? "(no title)" : item.title)
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()

                thumbnail
                    .frame(height: imageHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)

                Text(item.siteURL.isEmpty ? item.link : item.siteURL)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

            }
            .frame(height: 320)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(radius: 3, y: 2)
            )
        }
        // macOSで「ボタンっぽい青枠」やハイライトを消す
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .padding(14)
    }

    /// サムネ（thumbnailURL → siteImageURL → プレースホルダ）
    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.thumbnailURL {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                placeholder
            }
        } else if let url = item.siteImageURL {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Color.green.opacity(0.85))
            VStack(spacing: 6) {
                Text(item.siteTitle.isEmpty ? item.formatSiteTitle() : item.siteTitle)
                    .font(.title.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Image(systemName: "newspaper")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(8)
        }
    }

    /// サイトアイコン（siteImageURL があれば使う、なければ文字アイコン）
    @ViewBuilder
    private var siteIcon: some View {
        if let url = item.siteImageURL {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.1)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.1))
                Text(item.formatSiteInitial())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


#Preview {
    RssCardView(
        item: FeedItem(title: "Example News 1", link: "https://example.com/1", pubDate: Date(), thumbnailURL: nil, siteTitle: "iteeeeeeeewwwwwww"),
        onTap: {}
    )
}
