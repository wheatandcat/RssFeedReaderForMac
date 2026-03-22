import Foundation
@testable import RssFeedReader
import Testing

// MARK: - URLProtocol モック（ネットワーク不要なテスト用）

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

// MARK: - ArticleContentFetcherTests

struct ArticleContentFetcherTests {
    // MARK: - stripHTML: タグ除去

    @Test func stripHTMLRemovesBasicTags() {
        let html = "<html><body><p>Hello World</p></body></html>"
        let result = ArticleContentFetcher.stripHTML(from: html)
        #expect(result == "Hello World")
    }

    @Test func stripHTMLRemovesScriptBlocks() {
        let html = "<p>Content</p><script>alert('xss')</script><p>After</p>"
        let result = ArticleContentFetcher.stripHTML(from: html)
        #expect(!result.contains("alert"))
        #expect(result.contains("Content"))
        #expect(result.contains("After"))
    }

    @Test func stripHTMLRemovesStyleBlocks() {
        let html = "<style>body { color: red; }</style><p>Text</p>"
        let result = ArticleContentFetcher.stripHTML(from: html)
        #expect(!result.contains("color"))
        #expect(result.contains("Text"))
    }

    @Test func stripHTMLDecodesCommonEntities() {
        let html = "<p>&amp; &lt;tag&gt; &quot;quote&quot; &nbsp;space</p>"
        let result = ArticleContentFetcher.stripHTML(from: html)
        #expect(result.contains("&"))
        #expect(result.contains("<tag>"))
        #expect(result.contains("\"quote\""))
    }

    @Test func stripHTMLCollapsesWhitespace() {
        let html = "<p>Hello   \n\n   World</p>"
        let result = ArticleContentFetcher.stripHTML(from: html)
        #expect(result == "Hello World")
    }

    @Test func stripHTMLReturnsEmptyForEmptyInput() {
        let result = ArticleContentFetcher.stripHTML(from: "")
        #expect(result.isEmpty)
    }

    // MARK: - fetch: 2000文字トランケーション

    @Test func fetchTruncatesContentTo2000Characters() async throws {
        let longText = String(repeating: "a", count: 5000)
        let html = "<p>\(longText)</p>"
        let data = html.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let fetcher = ArticleContentFetcher(session: makeMockSession())
        let result = try await fetcher.fetch(url: URL(string: "https://example.com")!)
        #expect(result.count <= 2000)
    }

    // MARK: - fetch: HTTPエラー処理

    @Test func fetchThrowsOnHTTP404() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let fetcher = ArticleContentFetcher(session: makeMockSession())
        do {
            _ = try await fetcher.fetch(url: URL(string: "https://example.com")!)
            Issue.record("エラーがスローされるべき")
        } catch let ArticleContentFetcherError.httpError(code) {
            #expect(code == 404)
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    @Test func fetchThrowsOnHTTP500() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let fetcher = ArticleContentFetcher(session: makeMockSession())
        do {
            _ = try await fetcher.fetch(url: URL(string: "https://example.com")!)
            Issue.record("エラーがスローされるべき")
        } catch let ArticleContentFetcherError.httpError(code) {
            #expect(code == 500)
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    // MARK: - fetch: 空コンテンツ

    @Test func fetchThrowsOnEmptyContent() async {
        MockURLProtocol.requestHandler = { request in
            let html = "<html><body></body></html>"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, html.data(using: .utf8)!)
        }

        let fetcher = ArticleContentFetcher(session: makeMockSession())
        do {
            _ = try await fetcher.fetch(url: URL(string: "https://example.com")!)
            Issue.record("エラーがスローされるべき")
        } catch ArticleContentFetcherError.emptyContent {
            // 期待通り
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    // MARK: - fetch: 正常系

    @Test func fetchReturnsPlainTextFromHTML() async throws {
        let html = "<html><body><h1>Go言語入門</h1><p>Goはシンプルな言語です。</p></body></html>"
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, html.data(using: .utf8)!)
        }

        let fetcher = ArticleContentFetcher(session: makeMockSession())
        let result = try await fetcher.fetch(url: URL(string: "https://example.com")!)
        #expect(result.contains("Go言語入門"))
        #expect(result.contains("Goはシンプルな言語です。"))
        #expect(!result.contains("<h1>"))
        #expect(!result.contains("<p>"))
    }
}
