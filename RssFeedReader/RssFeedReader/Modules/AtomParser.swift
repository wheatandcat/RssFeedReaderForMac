import Foundation

/// Atom を最低限（title/link/updated/published/thumbnail）読む
final class AtomParser: NSObject, XMLParserDelegate {
    private var items: [FeedItem] = []
    private var currentItem: FeedItem?
    private var currentElement: String = ""
    private var buffer: String = ""
    private var pendingEnclosureImageURL: URL?
    private var inFeed: Bool = true
    private var siteTitle: String = ""
    private var siteURL: String = ""
    private var siteImageURL: URL? = nil
    
    // Atomの日付はISO8601が多い（小数秒あり/なし両対応）
    private let iso1 = ISO8601DateFormatter()
    private let iso2: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func parse(data: Data) throws -> [FeedItem] {
        items = []
        currentItem = nil
        currentElement = ""
        buffer = ""
        pendingEnclosureImageURL = nil
        siteTitle = ""
        siteURL = ""
        siteImageURL = nil

        let parser = XMLParser(data: data)
        parser.delegate = self
        if parser.parse() { return items }
        throw parser.parserError ?? NSError(domain: "AtomParser", code: 1)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {

        currentElement = elementName
        buffer = ""

        let name = elementName.lowercased()

        if name == "entry" {
            currentItem = FeedItem()
            pendingEnclosureImageURL = nil

            // ★ サイト情報を注入
            currentItem?.siteTitle = siteTitle
            currentItem?.siteURL = siteURL
            currentItem?.siteImageURL = siteImageURL
            return
        }

        // feed/link（サイトURL）: <link rel="alternate" href="..."/>
        if currentItem == nil, name == "link" {
            let rel = attributeDict["rel"]?.lowercased()
            if rel == nil || rel == "alternate",
               siteURL.isEmpty,
               let href = attributeDict["href"] {
                siteURL = href
            }
        }

        guard currentItem != nil else { return }

        // Atomのlinkは href属性（relで用途が分かれる）
        if name == "link" {
            let rel = attributeDict["rel"]?.lowercased() // nilはalternate扱いが多い
            let href = attributeDict["href"]
            let type = attributeDict["type"]?.lowercased()

            if let href, let url = URL(string: href) {
                // 通常リンク（優先：relがalternate or nil）
                if (rel == nil || rel == "alternate"), (currentItem?.link.isEmpty ?? true) {
                    currentItem?.link = href
                }

                // 高優先：media系（Atomでも出る）
                // ただし Atomのmedia:thumbnailは elementName に namespace が乗る場合があるので、qNameも見る
                // nameだけで拾えるケースが多いので最低限で対応
            }

            // 最下位：enclosureっぽいリンクが画像なら保留
            if rel == "enclosure",
               let href,
               let url = URL(string: href) {

                let isImageByType = (type?.hasPrefix("image/") == true)
                let isImageByExt = Self.isImageURL(url)

                if (isImageByType || isImageByExt), pendingEnclosureImageURL == nil {
                    pendingEnclosureImageURL = url
                }
            }

            return
        }

        // 高優先：media:thumbnail / media:content（url属性）
        if (name == "media:thumbnail" || name == "thumbnail" || name == "media:content" || name == "content"),
           let urlStr = attributeDict["url"],
           let url = URL(string: urlStr),
           currentItem?.thumbnailURL == nil {
            currentItem?.thumbnailURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        // feedメタ（entryの外側）
        if currentItem == nil {
            switch name {
            case "title":
                if siteTitle.isEmpty { siteTitle = text }
            case "logo", "icon":
                if siteImageURL == nil, let url = URL(string: text) {
                    siteImageURL = url
                }
            default:
                break
            }
        }
        
        guard var item = currentItem else { return }

        switch name {
        case "title":
            item.title += text

        case "updated", "published":
            // updated/published はどちらか新しい方を採用したいが、まずは入ってきたものをセット
            if let d = parseISO8601(text) {
                // 既に値があるなら “より新しい方” を残す
                if let existing = item.pubDate {
                    item.pubDate = max(existing, d)
                } else {
                    item.pubDate = d
                }
            }

        // 中優先：summary/contentのHTMLからimg
        case "summary", "content":
            if item.thumbnailURL == nil, let url = Self.firstImageURL(fromHTML: text) {
                item.thumbnailURL = url
            }

        case "entry":
            // 最下位：enclosure候補を採用
            if item.thumbnailURL == nil {
                item.thumbnailURL = pendingEnclosureImageURL
            }
            items.append(item)
            currentItem = nil
            pendingEnclosureImageURL = nil
            return

        default:
            break
        }

        currentItem = item
    }

    private func parseISO8601(_ s: String) -> Date? {
        // 小数秒あり/なし両対応
        return iso2.date(from: s) ?? iso1.date(from: s)
    }

    private static func isImageURL(_ url: URL) -> Bool {
        let exts: Set<String> = ["jpg","jpeg","png","gif","webp","bmp","tiff","heic","avif"]
        return exts.contains(url.pathExtension.lowercased())
    }

    private static func firstImageURL(fromHTML html: String) -> URL? {
        let pattern = #"(?i)<img[^>]+src\s*=\s*["']([^"']+)["']"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let m = re.firstMatch(in: html, range: range),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: html) else { return nil }
        return URL(string: String(html[r]))
    }
}
