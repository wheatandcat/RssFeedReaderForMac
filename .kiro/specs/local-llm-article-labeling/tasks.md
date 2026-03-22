# Implementation Plan

## Task Format
- `(P)` = 並行実行可能タスク
- `- [ ]*` = 後回し可能なテストカバレッジタスク

---

- [ ] 1. ラベルデータ基盤の実装
- [x] 1.1 FeedItemにlabelsフィールドを追加する
  - FeedItemモデルに `labels: [String]` プロパティをデフォルト値 `[]` で追加する
  - デフォルト値を空配列にすることで既存コードへの破壊的変更を防ぐ
  - _Requirements: 3.5_

- [x] 1.2 ラベルストアのデータモデルを実装する
  - 記事URL・ラベル配列・ラベリング日時を保持する `ArticleLabel` モデルを作成する
  - URLをキーとしてArticleLabelを保持する `LabelStore` モデルを作成する
  - どちらも `Codable` に準拠させ、UserDefaultsへのシリアライズに対応する
  - _Requirements: 3.2, 3.3_

- [x] 1.3 ラベルデータの永続化機能を実装する
  - `LabelStoreRepository` を作成し、バージョン付きキー `article-labels.v1` でUserDefaultsへのload/saveを実装する
  - 既存の `HistoryStoreRepository` と同一のJSONEncoder/Decoderパターンを踏襲する
  - 初回ロード時は空の `LabelStore` を返す
  - _Requirements: 3.1, 3.3, 3.4_

- [ ] 2. 記事コンテンツ取得機能の実装

- [x] 2.1 (P) 記事URLからプレーンテキストを取得するサービスを実装する
  - 記事URLに対してHTTPリクエストを送信し、HTMLレスポンスを取得する機能を実装する
  - 正規表現を使ってHTMLタグを除去し、プレーンテキストを抽出する
  - LLMのトークン節約のため先頭2000文字のみを返す
  - `URLRequest` に15秒タイムアウトを設定する
  - HTTP 200-299以外のステータスコードはエラーとして扱い、内容なしでスキップ処理できるようにする
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 3. OllamaラベリングサービスをTask2と並行して実装する

- [x] 3.1 (P) Ollama APIとの通信機能を実装する
  - `POST http://localhost:11434/api/chat` にリクエストを送信する機能を実装する
  - リクエストボディに `stream: false`・`format: "json"` を設定して同期JSON応答を受け取る
  - Codableな通信モデル（`OllamaChatRequest`・`OllamaChatResponse`）を定義して型安全なAPIアクセスを実現する
  - `URLRequest` に30秒タイムアウトを設定する
  - Ollama未起動・接続拒否・タイムアウト時はエラーをスローする
  - _Requirements: 2.1, 2.3_

- [x] 3.2 (P) ラベルセット定義とレスポンスバリデーションを実装する
  - 定義済みラベルセット（backend, frontend, go, AI等30種）を定数として定義する
  - システムプロンプトにラベルリストを含め、JSONフォーマットでラベルを返すよう指示するテンプレートを作成する
  - Ollamaのレスポンスをパースし、定義済みラベルセットとの交差集合のみを採用するバリデーションを実装する
  - 定義外ラベルは警告なしで除外し、空配列になっても正常処理とする
  - _Requirements: 2.2, 2.4, 2.5_

- [ ] 4. ラベルバッジ表示をTask2・Task3と並行して実装する

- [x] 4.1 (P) 記事カードにラベルバッジ表示を追加する
  - `RssCardView` に `labels` プロパティを受け取る仕組みを追加する
  - ラベルがある場合のみバッジ形式でラベルを表示するUIコンポーネントを実装する
  - `prefix(3)` で最大3件に絞り込み、超過分は表示しない
  - ラベルが空の場合はバッジ領域を描画せず既存レイアウトを保持する
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 5. バックグラウンドラベリングパイプラインの構築

- [x] 5.1 FeedViewModelにラベリングタスク起動機能を組み込む
  - `FeedViewModel` に `LabelStoreRepository` を持たせ、起動時に既存ラベルデータをロードする
  - `reloadAll()` 完了後にバックグラウンド `Task` としてラベリング処理を起動する
  - UI描画をブロックせず、`@MainActor` 境界を正しく使用してラベルデータを更新する
  - ラベリング完了後は `labelStore` の Published プロパティを更新して ForYouView のデータソースを最新化する
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 5.2 ラベリング済み記事のスキップ処理とTaskGroup並行実行を実装する
  - フィード取得で得た全記事のうち `labelStore.labelsByURL` に未登録のURLを持つ記事のみを抽出してラベリング対象とする
  - `withTaskGroup` を使い複数記事のコンテンツ取得とラベリングを並行実行する
  - 各記事のコンテンツ取得失敗・Ollama通信失敗はログ記録後に当該記事をスキップして次の記事の処理を継続する
  - ラベリング完了ごとに `LabelStoreRepository` に保存する
  - _Requirements: 4.4, 4.5_

- [ ] 6. For You おすすめ機能の実装

- [x] 6.1 閲覧履歴ラベルに基づくスコアリングロジックを実装する
  - `HistoryStore` から直近30日以内の閲覧エントリを抽出する
  - 各閲覧エントリのURLに対応するラベルを `LabelStore` から取得してラベル頻度マップを構築する
  - 未閲覧の全記事に対してラベル頻度マップとの積算スコアを計算する
  - スコア降順でソートし、スコアが1以上の記事のみを返す
  - _Requirements: 5.2, 5.5_

- [x] 6.2 For YouタブのViewを実装する
  - スコアリング済みのおすすめ記事リストをスクロールビューで表示するViewを実装する
  - 既存の `RssCardView` コンポーネントをそのまま再利用してカード表示を実現する
  - おすすめ記事が存在しない場合はガイダンスメッセージ（「おすすめ記事はまだありません。記事を読むと表示されます。」）を表示する
  - 記事タップ時はブラウザで記事URLを開き `FeedViewModel.recordHistory(item)` で閲覧記録を保存する
  - ファイル末尾に `#Preview` を追加してプレビュー可能にする
  - _Requirements: 5.1, 5.3, 5.4, 5.6_

- [x] 6.3 ContentViewのTabViewにFor Youタブを追加する
  - `ContentView` の `TabView` に For You タブを追加する
  - タブアイコンに `star.fill` を使用する
  - `ForYouView` に `FeedViewModel` のデータ（全記事・ラベルストア）と `HistoryStore` を渡す
  - _Requirements: 5.1_

- [x] 7. テストの実装

- [x] 7.1 ラベリングサービスのユニットテストを実装する
  - 定義外ラベルが返された場合に除外されることを検証するテストを作成する
  - Ollama未接続時に適切なエラーがスローされることを検証するテストを作成する
  - _Requirements: 2.3, 2.4_

- [x] 7.2 記事コンテンツ取得のユニットテストを実装する
  - HTML文字列からタグが除去されてプレーンテキストが返ることを検証するテストを作成する
  - 先頭2000文字に正しく切り詰められることを検証するテストを作成する
  - _Requirements: 1.2, 1.3_

- [x] 7.3 永続化とスコアリングのユニットテストを実装する
  - `LabelStoreRepository` がsave後にloadで同一データを返すことを検証するテストを作成する
  - `ForYouRecommender` が閲覧履歴ラベルに基づいて記事を正しくスコアリングし降順で返すことを検証するテストを作成する
  - _Requirements: 3.1, 5.5_

- [ ]* 7.4 バックグラウンドラベリングパイプラインの統合テストを実装する（任意）
  - `FeedViewModel` の `reloadAll()` 後にラベリングタスクが起動して `labelStore` が更新されることを検証する
  - 既ラベリング済み記事が再度ラベリングされないことを検証する
  - _Requirements: 4.1, 4.4_
