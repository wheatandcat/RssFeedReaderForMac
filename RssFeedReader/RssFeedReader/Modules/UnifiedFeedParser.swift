import Foundation

/// RSS/Atomを自動判別してパースする
final class UnifiedFeedParser {
    private let rss2 = RSSParser()
    private let atom = AtomParser()

    /// dataを見てRSS2 or Atomに振り分けてパースする
    func parse(data: Data) throws -> [FeedItem] {
        let root = Self.detectRootElementName(data: data)
     
        if root == "feed" {
            return try atom.parse(data: data)
        } else {
            // rss / rdf:RDF などはRSS系として扱う
            return try rss2.parse(data: data)
        }
    }

    /// XMLの先頭付近からルート要素名を雑に取り出す（高速・実用重視）
    private static func detectRootElementName(data: Data) -> String? {
        let prefix = data.prefix(8192)
        let s = String(decoding: prefix, as: UTF8.self)

        // XML宣言・DOCTYPE・コメントを飛ばして、最初の通常要素名を取る
        // 例: <feed ...> / <rss ...> / <rdf:RDF ...>
        let pattern = #"(?s)<\?(?:xml)[^>]*\?>\s*(?:<!--.*?-->\s*)*(?:<!DOCTYPE[^>]*>\s*)*<\s*([A-Za-z_][A-Za-z0-9_:\-\.]*)"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)

        // ① まず「XML宣言がある」前提で探す
        if let m = re.firstMatch(in: s, range: range),
           m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: s) {
            let name = String(s[r])
            return name.split(separator: ":").last.map(String.init)?.lowercased()
        }

        // ② XML宣言なしの場合のフォールバック
        let pattern2 = #"(?s)^\s*(?:<!--.*?-->\s*)*(?:<!DOCTYPE[^>]*>\s*)*<\s*([A-Za-z_][A-Za-z0-9_:\-\.]*)"#
        guard let re2 = try? NSRegularExpression(pattern: pattern2) else { return nil }
        if let m2 = re2.firstMatch(in: s, range: range),
           m2.numberOfRanges >= 2,
           let r2 = Range(m2.range(at: 1), in: s) {
            let name = String(s[r2])
            return name.split(separator: ":").last.map(String.init)?.lowercased()
        }

        return nil
    }
}
