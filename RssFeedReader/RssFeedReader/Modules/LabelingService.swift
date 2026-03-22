import Foundation

// MARK: - エラー型

enum LabelingServiceError: Error {
    case ollamaUnavailable
    case timeout
    case invalidResponse
    case noLabelsFound
}

// MARK: - Ollama API モデル

struct OllamaMessage: Encodable {
    let role: String
    let content: String
}

struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let format: String
}

struct OllamaResponseMessage: Decodable {
    let role: String
    let content: String
}

struct OllamaChatResponse: Decodable {
    let message: OllamaResponseMessage
    let done: Bool
}

// MARK: - ラベル解析用モデル

private struct LabelResponseBody: Decodable {
    let labels: [String]
}

// MARK: - LabelingService

protocol LabelingServiceProtocol {
    func label(content: String) async throws -> [String]
}

final class LabelingService: LabelingServiceProtocol {
    private let session: URLSession
    private let ollamaEndpoint = URL(string: "http://localhost:11434/api/chat")!
    private let modelName = "llama3.2:3b"

    static let supportedLabels: [String] = [
        // アーキテクチャ・設計
        "backend", "frontend", "web", "mobile", "desktop",
        "アーキテクチャ", "デザインパターン", "DDD", "マイクロサービス", "モノレポ",

        // 言語
        "go", "ruby", "python", "typescript", "javascript", "rust",
        "swift", "kotlin", "java", "php", "scala", "elixir", "c++",

        // フレームワーク・ライブラリ
        "react", "vue", "next", "nuxt", "angular", "svelte",
        "rails", "django", "fastapi", "laravel", "spring", "nestjs", "express",
        "flutter",

        // スタイル・API
        "css", "graphql", "gRPC", "REST",

        // DB・ストレージ
        "db", "mysql", "postgres", "redis", "mongodb", "elasticsearch",
        "sqlite", "dynamodb", "orm",

        // インフラ・DevOps
        "docker", "kubernetes", "terraform", "linux", "nginx",
        "CI/CD", "github actions",

        // クラウド・PaaS
        "GCP", "AWS", "azure", "cloudflare", "firebase", "supabase", "vercel",

        // SRE・運用
        "sre", "cre", "monitoring", "observability", "セキュリティ",

        // AI・ツール
        "AI", "LLM", "RAG", "claude code", "cursor", "codex", "copilot",

        // 開発ツール・プラットフォーム
        "github", "vscode", "vim", "neovim",

        // iOS / macOS / Android
        "ios", "android", "swiftui", "xcode",

        // テスト・品質
        "テスト", "TDD", "パフォーマンス", "アクセシビリティ",

        // キャリア・組織
        "マネージング", "チームビルディング", "キャリア", "採用",
    ]

    private var systemPrompt: String {
        let labelList = Self.supportedLabels.joined(separator: ", ")
        return """
        あなたは技術記事の分類専門家です。
        以下のラベルリストから記事に合うものをすべて選び、JSONで返してください。
        ラベルリスト: \(labelList)
        返答形式: {"labels": ["label1", "label2"]}
        """
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func label(content: String) async throws -> [String] {
        let requestBody = OllamaChatRequest(
            model: modelName,
            messages: [
                OllamaMessage(role: "system", content: systemPrompt),
                OllamaMessage(role: "user", content: content)
            ],
            stream: false,
            format: "json"
        )

        var request = URLRequest(url: ollamaEndpoint, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LabelingServiceError.invalidResponse
        }

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch let urlError as NSError {
            let connectionErrorCodes = [
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut
            ]
            if urlError.code == NSURLErrorTimedOut {
                throw LabelingServiceError.timeout
            }
            if connectionErrorCodes.contains(urlError.code) {
                throw LabelingServiceError.ollamaUnavailable
            }
            throw LabelingServiceError.ollamaUnavailable
        }

        // Ollama レスポンスをデコード
        let ollamaResponse: OllamaChatResponse
        do {
            ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        } catch {
            throw LabelingServiceError.invalidResponse
        }

        // レスポンス content を JSON としてパースしラベルを抽出
        let contentString = ollamaResponse.message.content
        guard let contentData = contentString.data(using: .utf8),
              let labelBody = try? JSONDecoder().decode(LabelResponseBody.self, from: contentData)
        else {
            throw LabelingServiceError.invalidResponse
        }

        // 定義済みラベルセットとの交差集合のみ返す（大文字小文字を無視して照合）
        print("[LabelingService] raw labels from Ollama: \(labelBody.labels)")
        let filtered = labelBody.labels.compactMap { raw -> String? in
            Self.supportedLabels.first { $0.lowercased() == raw.lowercased() }
        }

        // 20件以上は一覧記事とみなしてラベルなし扱い
        if filtered.count >= 20 {
            print("[LabelingService] too many labels (\(filtered.count)), treating as list article")
            return []
        }

        return filtered
    }
}
