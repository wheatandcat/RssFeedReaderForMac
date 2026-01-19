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
}
