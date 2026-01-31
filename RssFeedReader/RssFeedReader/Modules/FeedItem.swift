import Foundation

struct FeedItem: Identifiable, Hashable {
    let id = UUID()
    var title: String = ""
    var link: String = ""
    var pubDate: Date? = nil
    var thumbnailURL: URL? = nil

    var siteTitle: String = ""
    var siteURL: String = ""
    var siteImageURL: URL? = nil
    var sourceFeedURL: String = ""

    var stableID: String = ""
    var isNew: Bool = false
}

extension FeedItem {
    func formatSiteTitle() -> String {
        let siteName = siteTitle.split(separator: " ").first.map(String.init)

        return siteName ?? ""
    }

    /// siteTitleが空のときに使うフォールバック（例：URLホスト名）
    func formatSiteTitleFallback() -> String {
        if let u = URL(string: siteURL), let host = u.host { return host }
        if let u = URL(string: link), let host = u.host { return host }
        return "Unknown"
    }

    /// サイトの頭文字（アイコンが無いとき用）
    func formatSiteInitial() -> String {
        let s = (siteTitle.isEmpty ? formatSiteTitleFallback() : siteTitle)
        return String(s.prefix(1)).uppercased()
    }
}
