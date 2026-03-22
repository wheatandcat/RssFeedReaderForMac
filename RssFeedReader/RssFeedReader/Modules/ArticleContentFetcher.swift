import Foundation

enum ArticleContentFetcherError: Error {
    case httpError(statusCode: Int)
    case emptyContent
}

protocol ArticleContentFetchable {
    func fetch(url: URL) async throws -> String
}

final class ArticleContentFetcher: ArticleContentFetchable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw ArticleContentFetcherError.httpError(statusCode: http.statusCode)
        }

        let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        let text = Self.stripHTML(from: html)

        if text.isEmpty {
            throw ArticleContentFetcherError.emptyContent
        }

        return String(text.prefix(2000))
    }

    static func stripHTML(from html: String) -> String {
        var result = html

        // script / style ブロックを除去
        result = result.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: " ",
            options: .regularExpression
        )

        // 残りの HTML タグを除去
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // 主要な HTML エンティティをデコード
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")

        // 連続する空白・改行を単一スペースに正規化
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
