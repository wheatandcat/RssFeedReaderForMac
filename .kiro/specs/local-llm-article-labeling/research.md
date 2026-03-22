# Research & Design Decisions

---
**Purpose**: Capture discovery findings, architectural investigations, and rationale that inform the technical design.

---

## Summary
- **Feature**: `local-llm-article-labeling`
- **Discovery Scope**: Complex Integration（新規機能 + 外部ローカルAPI統合）
- **Key Findings**:
  - Ollama は `POST http://localhost:11434/api/chat` に `stream: false` + `format: "json"` を指定することで同期JSON応答が得られ、Swift の URLSession パターンと完全に適合する
  - 軽量モデルとして **Llama 3.2:3b**（~2GB）が macOS 8GB RAM 環境で動作し、テキスト分類に十分な精度を持つ
  - 外部Swiftライブラリ不要：標準 `URLSession` + `Codable` で Ollama API を呼び出せる
  - HTML テキスト抽出は正規表現によるタグ除去で十分（XMLParser は RSS 専用のため流用しない）
  - UserDefaults への大量データ保存は ~4MB 制限があるため、ラベルデータは URL + ラベル配列のみに絞り最小化が必要

---

## Research Log

### Ollama REST API 仕様

- **Context**: ローカルLLM統合の具体的なAPIエンドポイントと通信形式の確認
- **Sources Consulted**:
  - https://docs.ollama.com/api/introduction
  - https://github.com/ollama/ollama/blob/main/docs/api.md
- **Findings**:
  - エンドポイント: `POST http://localhost:11434/api/chat`
  - リクエスト: `{ "model": "llama3.2:3b", "messages": [...], "stream": false, "format": "json" }`
  - レスポンス（stream: false）: `{ "message": { "role": "assistant", "content": "..." }, "done": true }`
  - `format: "json"` 指定でモデルにJSON形式のレスポンスを強制できる
  - デフォルトはストリーミング（stream: true）なので `stream: false` の明示が必須
  - 接続タイムアウトのデフォルト値なし → 30秒タイムアウトを設定推奨
- **Implications**: URLSession の POST リクエストで直接呼び出し可能。外部ライブラリ不要で「外部依存ゼロ」方針を維持できる。

### 軽量モデル選定

- **Context**: macOS 環境で動作する最適なラベリングモデルの選定
- **Sources Consulted**:
  - https://localllm.in/blog/ollama-vram-requirements-for-local-llms
  - Ollama モデルライブラリ
- **Findings**:
  - Llama 3.2:3b — ~2GB、8GB RAM必要、20-25 tokens/sec、テキスト分類に十分
  - Phi-4 Mini:3.8b — ~2.3GB、8GB RAM必要、15-20 tokens/sec、超軽量
  - Mistral 7B — ~4GB、16GB RAM推奨、より高精度
  - **推奨**: `llama3.2:3b`（速度・精度・メモリのバランスが最良）
- **Implications**: デフォルトモデルは `llama3.2:3b` を設定。モデル名は設定可能にすることが望ましいが、本フェーズではハードコードで可。

### HTMLテキスト抽出方法

- **Context**: 記事URLのHTMLコンテンツからプレーンテキストを抽出する方法
- **Sources Consulted**: 既存コードベース調査（RSSParser, AtomParser）
- **Findings**:
  - 既存の XMLParser は RSS/Atom XML 専用であり HTML には不適
  - SwiftUI アプリでの軽量 HTML テキスト化には正規表現によるタグ除去が最もシンプル
  - NSAttributedString の HTML 初期化はメインスレッド依存のため非同期処理と相性が悪い
  - 記事本文の最初 2000 文字程度あればラベリングに十分（トークン節約）
- **Implications**: `ArticleContentFetcher` で正規表現によるタグ除去 + 先頭2000文字トリミングを採用。

### スコアリングアルゴリズム設計

- **Context**: 直近閲覧記事のラベルから未閲覧記事を推薦するスコアリング方法
- **Sources Consulted**: collaborative filtering および content-based filtering の基本文献
- **Findings**:
  - **単純頻度カウント**: 直近30日の閲覧記事から各ラベルの出現回数を集計し、未閲覧記事のラベルとの積算スコアで順位付け
  - **時間減衰**: 最近閲覧した記事ほど高スコア → 複雑度が増す
  - 本機能のデータ量（数十〜数百記事）では単純頻度カウントで十分な精度
- **Implications**: `ForYouRecommender`（`ForYouView`内）では単純頻度カウント方式を採用。実装がシンプルで将来の置き換えも容易。

### UserDefaults 容量制限

- **Context**: 多数記事のラベルデータをUserDefaultsに保存できるかの確認
- **Findings**:
  - UserDefaults は公式には容量制限なし（実装依存、通常 ~4MB が実用上限）
  - 1記事 = URL(~100B) + labels配列(~5ラベル×20B=100B) + date(~30B) = ~230B
  - 1000記事で約230KB → 問題なし
  - ただし古いエントリのクリーンアップポリシーがあると望ましい
- **Implications**: 保存データを URL・ラベル・日時のみに最小化。最大1000件でクリーンアップを将来課題とする。

---

## Architecture Pattern Evaluation

| Option | 説明 | 強み | リスク | 評価 |
|--------|------|------|--------|------|
| A: FeedViewModel 拡張 | FeedViewModelにラベリングロジック追加 | ファイル数最小 | ViewModel肥大化、テスト困難 | 非推奨 |
| B: 完全新規コンポーネント群 | 独立したService・Repository・View | 単一責任、テスト容易 | ファイル数増加（+6） | 推奨 |
| C: ハイブリッド | B の変形で ForYouRecommender を ForYouView に統合 | ファイル数削減 | スコアリング複雑化時に分離必要 | 代替案 |

**採用: Option B** — 既存 `HistoryStoreRepository` パターンが完全流用可能であり、ファイル追加コストは低い。FeedViewModelへの混入によるアーキテクチャ劣化リスクが高いため。

---

## Design Decisions

### Decision: Ollama API エンドポイント選択（/api/generate vs /api/chat）

- **Context**: ラベリング用プロンプトを投げる際の最適エンドポイントの選択
- **Alternatives Considered**:
  1. `/api/generate` — テキスト補完、シンプルなプロンプト文字列
  2. `/api/chat` — メッセージ配列形式、`format: "json"` 対応あり
- **Selected Approach**: `/api/chat` を使用
- **Rationale**: `format: "json"` フィールドでモデルにJSON応答を強制できるため、ラベル配列のパースが確実になる。システムプロンプトとユーザープロンプトの分離も明確。
- **Trade-offs**: リクエストボディが若干複雑になるが、レスポンスパースの信頼性が向上する
- **Follow-up**: プロンプトテンプレートの調整がモデルによって必要になる可能性あり

### Decision: HTMLテキスト抽出方法（正規表現 vs NSAttributedString）

- **Context**: 記事HTMLから本文テキストを取り出す実装方法
- **Alternatives Considered**:
  1. 正規表現によるHTMLタグ除去 — シンプル、非同期対応
  2. NSAttributedString のHTML初期化 — 高精度だがメインスレッド制約あり
- **Selected Approach**: 正規表現によるタグ除去 + 先頭2000文字
- **Rationale**: 非同期バックグラウンド処理との相性が良く、外部依存なし。ラベリング精度には2000文字で十分。
- **Trade-offs**: 複雑なHTMLレイアウトでノイズが残る可能性があるが、LLMが吸収する

### Decision: ラベリング起動タイミング

- **Context**: ラベリングタスクをどのタイミングでどのように起動するか
- **Alternatives Considered**:
  1. `reloadAll()` 完了直後に起動 — データが揃った直後
  2. 記事カードタップ時（閲覧時）に起動 — 閲覧済みのみラベリング
- **Selected Approach**: `reloadAll()` 完了後にバックグラウンド Task で起動（未ラベリング全記事対象）
- **Rationale**: For You タブでの推薦には未閲覧記事のラベルも必要なため、閲覧時限定では不十分
- **Trade-offs**: 初回起動時に大量タスクが発生するが、既ラベリング済みスキップで回数は漸減

---

## Risks & Mitigations

- **Ollama 未起動** — `LabelingService` がタイムアウト後にエラーをログ記録してサイレントスキップ。UIへの影響なし。
- **モデル未ダウンロード** — 接続エラーとして扱い、同上のサイレントスキップ。設定画面での案内は将来課題。
- **LLMが定義外ラベルを返す** — レスポンスを定義済みラベルセットとの差集合でフィルタリング。
- **UserDefaults書き込み競合** — ラベル保存は`@MainActor`のFeedViewModelから呼び出し、シリアルに実行。
- **HTML取得のタイムアウト** — URLSession に15秒タイムアウトを設定し、超過時スキップ。

---

## References

- [Ollama API Documentation](https://docs.ollama.com/api/introduction)
- [Ollama GitHub API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama VRAM Requirements](https://localllm.in/blog/ollama-vram-requirements-for-local-llms)
