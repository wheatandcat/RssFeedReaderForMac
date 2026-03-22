@testable import RssFeedReader
import Foundation
import Testing

// MockOllamaURLProtocol は LabelingServiceOllamaTests.swift で定義済み

private func makeMockValidationSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockOllamaURLProtocol.self]
    return URLSession(configuration: config)
}


struct LabelingServiceValidationTests {

    // MARK: - supportedLabels 定義

    @Test func supportedLabelsContainsAllRequiredTechLabels() {
        let labels = LabelingService.supportedLabels
        let required = [
            "backend", "frontend", "sre", "cre", "db", "mysql", "postgres",
            "orm", "web", "react", "vue", "next", "css", "graphql", "gRPC",
            "go", "ruby", "rails", "マネージング", "チームビルディング",
            "AI", "cloudflare", "GCP", "AWS", "claude code", "cursor",
            "codex", "github", "CI/CD"
        ]
        for label in required {
            #expect(labels.contains(label), "'\(label)' が supportedLabels に含まれていない")
        }
    }

    @Test func supportedLabelsHasAtLeast29Entries() {
        #expect(LabelingService.supportedLabels.count >= 29)
    }

    @Test func supportedLabelsHasNoDuplicates() {
        let labels = LabelingService.supportedLabels
        let unique = Set(labels)
        #expect(labels.count == unique.count)
    }

    // MARK: - 定義外ラベルのフィルタリング

    @Test func unsupportedLabelsAreFilteredOut() async throws {
        MockOllamaURLProtocol.requestHandler = { request in
            // Ollama が定義外ラベルを返す
            let json = """
            {
                "model": "llama3.2:3b",
                "message": {
                    "role": "assistant",
                    "content": "{\\"labels\\": [\\"go\\", \\"kotlin\\", \\"swift\\", \\"backend\\"]}"
                },
                "done": true
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let service = LabelingService(session: makeMockValidationSession())
        let labels = try await service.label(content: "Go言語のバックエンド記事")

        // "kotlin" と "swift" は定義外なので除外される
        #expect(labels.contains("go"))
        #expect(labels.contains("backend"))
        #expect(!labels.contains("kotlin"))
        #expect(!labels.contains("swift"))
    }

    @Test func returnsEmptyArrayWhenAllLabelsAreUnsupported() async throws {
        MockOllamaURLProtocol.requestHandler = { request in
            let json = """
            {
                "model": "llama3.2:3b",
                "message": {
                    "role": "assistant",
                    "content": "{\\"labels\\": [\\"kotlin\\", \\"swift\\", \\"flutter\\"]}"
                },
                "done": true
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let service = LabelingService(session: makeMockValidationSession())
        let labels = try await service.label(content: "モバイル開発記事")

        // 定義外のみなので空配列が返る（エラーにはならない）
        #expect(labels.isEmpty)
    }

    // MARK: - 複数ラベル付与

    @Test func returnsMultipleMatchingLabels() async throws {
        MockOllamaURLProtocol.requestHandler = { request in
            let json = """
            {
                "model": "llama3.2:3b",
                "message": {
                    "role": "assistant",
                    "content": "{\\"labels\\": [\\"go\\", \\"backend\\", \\"GCP\\", \\"CI/CD\\"]}"
                },
                "done": true
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let service = LabelingService(session: makeMockValidationSession())
        let labels = try await service.label(content: "GoでGCP上にCI/CDパイプラインを構築する記事")

        #expect(labels.count == 4)
        #expect(labels.contains("go"))
        #expect(labels.contains("backend"))
        #expect(labels.contains("GCP"))
        #expect(labels.contains("CI/CD"))
    }

    // MARK: - 空ラベル配列

    @Test func returnsEmptyArrayWhenOllamaReturnsEmptyLabels() async throws {
        MockOllamaURLProtocol.requestHandler = { request in
            let json = """
            {
                "model": "llama3.2:3b",
                "message": {
                    "role": "assistant",
                    "content": "{\\"labels\\": []}"
                },
                "done": true
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let service = LabelingService(session: makeMockValidationSession())
        let labels = try await service.label(content: "分類できない記事")

        // 空配列を正常として扱う（エラーにしない）
        #expect(labels.isEmpty)
    }
}
