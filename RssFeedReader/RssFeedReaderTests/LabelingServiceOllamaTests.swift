@testable import RssFeedReader
import Foundation
import Testing

// ArticleContentFetcherTests で定義済みの MockURLProtocol を再利用するため、
// ここでは MockOllamaURLProtocol を別名で定義する

final class MockOllamaURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockOllamaURLProtocol.requestHandler else {
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

private func makeMockOllamaSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockOllamaURLProtocol.self]
    return URLSession(configuration: config)
}

private func ollamaResponse(labels: [String]) -> Data {
    let labelsJSON = labels.map { "\"\($0)\"" }.joined(separator: ", ")
    let content = "{\"labels\": [\(labelsJSON)]}"
    let json = """
    {
        "model": "llama3.2:3b",
        "message": {
            "role": "assistant",
            "content": "\(content.replacingOccurrences(of: "\"", with: "\\\""))"
        },
        "done": true
    }
    """
    return json.data(using: .utf8)!
}

struct LabelingServiceOllamaTests {

    // MARK: - リクエスト送信

    @Test func sendsPOSTRequestToOllamaEndpoint() async throws {
        var capturedRequest: URLRequest?

        MockOllamaURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, ollamaResponse(labels: ["go"]))
        }

        let service = LabelingService(session: makeMockOllamaSession())
        _ = try await service.label(content: "Go言語の記事です。")

        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.url?.absoluteString == "http://localhost:11434/api/chat")
    }

    @Test func requestBodyContainsStreamFalseAndFormatJson() async throws {
        var capturedBody: [String: Any]?

        MockOllamaURLProtocol.requestHandler = { request in
            if let body = request.httpBody {
                capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, ollamaResponse(labels: ["go"]))
        }

        let service = LabelingService(session: makeMockOllamaSession())
        _ = try await service.label(content: "テスト記事")

        #expect(capturedBody?["stream"] as? Bool == false)
        #expect(capturedBody?["format"] as? String == "json")
    }

    // MARK: - レスポンス解析

    @Test func parsesLabelsFromOllamaResponse() async throws {
        MockOllamaURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, ollamaResponse(labels: ["go", "backend"]))
        }

        let service = LabelingService(session: makeMockOllamaSession())
        let labels = try await service.label(content: "Go言語のバックエンド開発記事")

        #expect(labels.contains("go"))
        #expect(labels.contains("backend"))
    }

    @Test func throwsInvalidResponseOnMalformedJSON() async {
        MockOllamaURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json at all".data(using: .utf8)!)
        }

        let service = LabelingService(session: makeMockOllamaSession())
        do {
            _ = try await service.label(content: "記事")
            Issue.record("エラーがスローされるべき")
        } catch LabelingServiceError.invalidResponse {
            // 期待通り
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    // MARK: - エラーハンドリング

    @Test func throwsOllamaUnavailableOnConnectionError() async {
        MockOllamaURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)
        }

        let service = LabelingService(session: makeMockOllamaSession())
        do {
            _ = try await service.label(content: "記事")
            Issue.record("エラーがスローされるべき")
        } catch LabelingServiceError.ollamaUnavailable {
            // 期待通り
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }

    @Test func throwsOllamaUnavailableOnNetworkUnreachable() async {
        MockOllamaURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        }

        let service = LabelingService(session: makeMockOllamaSession())
        do {
            _ = try await service.label(content: "記事")
            Issue.record("エラーがスローされるべき")
        } catch LabelingServiceError.ollamaUnavailable {
            // 期待通り
        } catch {
            Issue.record("予期しないエラー: \(error)")
        }
    }
}
