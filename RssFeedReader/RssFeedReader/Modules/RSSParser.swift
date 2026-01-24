import Foundation

final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [FeedItem] = []
    private var currentItem: FeedItem?
    private var currentElement: String = ""
    private var buffer: String = ""
    private var siteTitle = ""
    private var siteURL = ""
    private var siteImageURL: URL?
    private var inChannel = false
    private var inImage = false

    private lazy var rfc822: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parse(data: Data) throws -> [FeedItem] {
        items = []
        currentItem = nil
        currentElement = ""
        buffer = ""
        siteTitle = ""
        siteURL = ""
        siteImageURL = nil
        inChannel = false
        inImage = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        if parser.parse() { return items }
        throw parser.parserError ?? NSError(domain: "RSSParser", code: 1)
    }

    func parser(_: XMLParser, didStartElement elementName: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes attributeDict: [String: String] = [:])
    {
        currentElement = elementName
        buffer = ""

        let name = elementName.lowercased()

        if name == "channel" {
            inChannel = true
            return
        }
        if name == "image", inChannel {
            inImage = true
            return
        }

        if name == "item" {
            currentItem = FeedItem()
            currentItem?.siteTitle = siteTitle
            currentItem?.siteURL = siteURL
            currentItem?.siteImageURL = siteImageURL
            return
        }

        if inChannel, name == "itunes:image" || name == "image",
           let href = attributeDict["href"], let url = URL(string: href)
        {
            if siteImageURL == nil { siteImageURL = url }
        }

        if let _ = currentItem {
            let name = elementName.lowercased()
            if name == "media:thumbnail" || name == "thumbnail" || name == "media:content" || name == "content",
               let urlStr = attributeDict["url"],
               let url = URL(string: urlStr)
            {
                // 既に設定済みなら上書きしない（最初に取れたものを優先）
                if currentItem?.thumbnailURL == nil {
                    currentItem?.thumbnailURL = url
                }
            }

            if name == "enclosure",
               let type = attributeDict["type"]?.lowercased(),
               type.hasPrefix("image/"),
               let urlStr = attributeDict["url"],
               let url = URL(string: urlStr)
            {
                if currentItem?.thumbnailURL == nil {
                    currentItem?.thumbnailURL = url
                }
            }

            if name == "enclosure",
               let urlStr = attributeDict["url"],
               let url = URL(string: urlStr),
               isImageURL(url)
            {
                if currentItem?.thumbnailURL == nil {
                    currentItem?.thumbnailURL = url
                }
            }
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_: XMLParser, didEndElement elementName: String,
                namespaceURI _: String?, qualifiedName _: String?)
    {
        let name = elementName.lowercased()
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        // channelメタデータ（itemの外側）
        if inChannel, currentItem == nil {
            switch name {
            case "title":
                // channel/title
                if siteTitle.isEmpty { siteTitle = text }
            case "link":
                // channel/link
                if siteURL.isEmpty { siteURL = text }
            case "url":
                // channel/image/url
                if inImage, siteImageURL == nil, let url = URL(string: text) {
                    siteImageURL = url
                }
            case "image":
                inImage = false
            case "channel":
                inChannel = false
            default:
                break
            }
        }

        guard var item = currentItem else { return }

        switch elementName.lowercased() {
        case "title":
            item.title += text

        case "link":
            item.link += text

        case "pubdate":
            item.pubDate = rfc822.date(from: text)

        // 3) description / content:encoded から <img src="..."> を拾う（最後の砦）
        case "description", "content:encoded", "encoded":
            if item.thumbnailURL == nil, let url = Self.firstImageURL(fromHTML: text) {
                item.thumbnailURL = url
            }

        case "item":
            items.append(item)
            currentItem = nil
            return

        default:
            break
        }

        currentItem = item
    }

    /// HTML文字列から最初の img src を雑に拾う（RSSのdescriptionは簡易HTMLが多い前提）
    private static func firstImageURL(fromHTML html: String) -> URL? {
        // src='...' / src="..." 両対応（雑だけど実用上かなり効く）
        let pattern = #"(?i)<img[^>]+src\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex ..< html.endIndex, in: html)
        guard let m = regex.firstMatch(in: html, range: range),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: html) else { return nil }

        let urlStr = String(html[r])
        return URL(string: urlStr)
    }

    private func isImageURL(_ url: URL) -> Bool {
        let imageExtensions: Set<String> = [
            "jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic", "avif",
        ]

        let ext = url.pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }
}
