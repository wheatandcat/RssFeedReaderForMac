# ギャップ分析レポート

**フィーチャー**: local-llm-article-labeling
**作成日**: 2026-03-21
**分析対象**: 既存コードベース vs 要件 (requirements.md)

---

## 1. 現状調査サマリー

### 既存ファイル構成（16ファイル）

```
RssFeedReader/
├── RssFeedReaderApp.swift         # @main エントリポイント
├── ContentView.swift              # TabView（RSS / Settings / History）
├── Modules/
│   ├── FeedViewModel.swift        # @MainActor, ObservableObject 中心ロジック
│   ├── FeedItem.swift             # 記事モデル（id, title, link, pubDate, ...）
│   ├── Feed.swift                 # フィード設定モデル
│   ├── SeenStore.swift            # 既読管理モデル
│   ├── HistoryEntry.swift         # 閲覧履歴エントリ
│   ├── HistoryStore.swift         # 閲覧履歴モデル
│   ├── HistoryStoreRepository.swift  # 履歴の load/save (key: "history-store.v1")
│   ├── UnifiedFeedParser.swift    # RSS/Atom 判定ルーター
│   ├── RSSParser.swift            # RSS 2.0 パーサー
│   └── AtomParser.swift           # Atom パーサー
└── Pages/
    ├── RssView.swift              # 記事一覧グリッド
    ├── RssCardView.swift          # 記事カードコンポーネント
    ├── HistoryView.swift          # 閲覧履歴一覧
    └── SettingView.swift          # フィード管理
```

### 主要な既存パターン

| パターン | 詳細 |
|---|---|
| 永続化 | UserDefaults + JSONEncoder/Decoder、バージョン付きキー（`feeds.v1`, `history-store.v1`, `seen-store.v1`） |
| HTTP通信 | `URLSession.shared.data(from:)` async/await |
| 並行処理 | `withTaskGroup` でフィード並行取得 |
| ViewModelスレッド安全 | `@MainActor final class FeedViewModel` |
| タブ構造 | `ContentView` の `TabView` に3タブ（RSS / Settings / History） |
| Repository | `HistoryStoreRepository`, `SeenStoreRepository` がload/saveを担当 |

---

## 2. 要件対既存アセット マッピング

### Requirement 1: 記事コンテンツ取得

| 技術的要素 | 現状 | ギャップ |
|---|---|---|
| URLSession HTTP取得 | ✅ 存在（RSSフィード取得に使用） | HTMLコンテンツ取得は未実装 |
| HTMLテキスト抽出 | ❌ なし | HTMLパーサーが必要（XMLParser は RSS/Atom 専用） |
| バックグラウンド非同期実行 | ✅ `withTaskGroup` パターン存在 | 記事URL向けのTask管理は未実装 |
| エラーハンドリング（スキップ継続） | ✅ フィード取得でdo-catch済み | 流用可能 |

**ギャップ評価**: `ArticleContentFetcher` サービスが **Missing**

---

### Requirement 2: ローカルLLMによるラベリング

| 技術的要素 | 現状 | ギャップ |
|---|---|---|
| ローカルLLM API呼び出し | ❌ なし | Ollama REST API (localhost:11434) への HTTP クライアントが必要 |
| ラベルセット定義 | ❌ なし | 30種のラベル定数が未定義 |
| 複数ラベル付与ロジック | ❌ なし | LLMレスポンスのパース・バリデーション未実装 |
| LLM未起動時のフォールバック | ❌ なし | エラーハンドリングが必要 |

**ギャップ評価**: `LabelingService` 全体が **Missing**
**注意**: Ollama は localhost への HTTP 呼び出しのため、外部依存ゼロポリシーには抵触しないが、ユーザー環境に Ollama インストールが必要（**Research Needed**）

---

### Requirement 3: ラベリング結果の永続化

| 技術的要素 | 現状 | ギャップ |
|---|---|---|
| UserDefaults + JSONEncoder 永続化 | ✅ `HistoryStoreRepository` が完全なパターンを提供 | LabelStore用のRepキーが未定義 |
| バージョン付きキー | ✅ `"history-store.v1"` パターン存在 | `"article-labels.v1"` が必要 |
| LabelStoreRepository | ❌ なし | **Missing** |
| LabelStore モデル | ❌ なし | **Missing** |

**ギャップ評価**: `HistoryStoreRepository` を参考に完全流用可能なパターンが確立済み。実装コストは低い。

---

### Requirement 4: 非同期バックグラウンドラベリング

| 技術的要素 | 現状 | ギャップ |
|---|---|---|
| withTaskGroup 並行処理 | ✅ `reloadAll()` で確立済み | ラベリング向けTaskGroupが未実装 |
| 既処理スキップ判定 | ✅ SeenStore でパターン存在 | ラベル済みURLの判定ロジックが未実装 |
| UIブロッキング回避 | ✅ @MainActor + async パターン | ラベリングタスクが別Taskとして分離が必要 |
| reloadAll() 後のトリガー | ✅ 呼び出しポイント特定済み | ラベリング起動コードの追加が必要 |

**ギャップ評価**: 既存パターンで対応可能だが `FeedViewModel.reloadAll()` への追加が必要

---

### Requirement 5: For You タブ

| 技術的要素 | 現状 | ギャップ |
|---|---|---|
| TabView への新タブ追加 | ✅ `ContentView.swift` の TabView に追加可能 | For You タブが **Missing** |
| ForYouView | ❌ なし | **Missing** |
| おすすめスコアリングロジック | ❌ なし | 直近30日閲覧履歴 × ラベル頻度の算出が **Missing** |
| 閲覧履歴アクセス | ✅ `HistoryStoreRepository` 存在、FeedViewModel で管理 | 読み取りは可能 |
| RssCardView 再利用 | ✅ 既存コンポーネントそのまま利用可能 | レイアウトの流用のみ |
| 閲覧なし時のガイダンス | ❌ なし | 空状態UIが必要 |

**ギャップ評価**: ForYouView + スコアリングロジックが **Missing**
**Research Needed**: スコアリングアルゴリズムの詳細設計（TF-IDF風か単純頻度カウントか）

---

### Requirement 6: ラベル表示（オプション）

| 技術的要素 | 現状 | ギャップ |
|---|---|---|
| RssCardView へのバッジ追加 | ✅ ファイル特定済み | バッジUIコンポーネントが **Missing** |
| FeedItem へのラベルフィールド追加 | ❌ なし | `labels: [String]` フィールドが **Missing** |
| ラベル最大3件表示 | ❌ なし | 表示ロジックが必要 |

---

## 3. 実装アプローチ比較

### Option A: FeedViewModel 中心拡張

既存の `FeedViewModel` にラベリングロジックを集約する。

**変更ファイル**: `FeedViewModel.swift`, `FeedItem.swift`, `ContentView.swift`, `RssCardView.swift`
**新規ファイル**: `LabelStore.swift`, `LabelStoreRepository.swift`

- ✅ 新規ファイルが最小限
- ❌ FeedViewModel がさらに肥大化（すでに100行超）
- ❌ ラベリング・LLM通信ロジックが ViewModel に混在しアーキテクチャが崩れる
- ❌ 単体テストが困難

**評価**: 非推奨

---

### Option B: 完全新規コンポーネント群

全機能を新規ファイルとして作成し、FeedViewModelへの変更を最小限にする。

**新規ファイル**:
- `Modules/LabelStore.swift`
- `Modules/LabelStoreRepository.swift`
- `Modules/ArticleContentFetcher.swift`
- `Modules/LabelingService.swift`
- `Modules/ForYouRecommender.swift`
- `Pages/ForYouView.swift`

**変更ファイル**: `FeedItem.swift`（labels追加）, `ContentView.swift`（タブ追加）, `FeedViewModel.swift`（ラベリング起動のみ）

- ✅ 単一責任原則を維持
- ✅ 各コンポーネントの独立テストが容易
- ✅ FeedViewModel の肥大化を防ぐ
- ❌ ファイル数が増加（+6ファイル）

**評価**: 推奨

---

### Option C: ハイブリッド（Repository + Service 新規 + ViewModel 最小変更）

Option B と同等だが、`ForYouRecommender` を独立クラスとせず `ForYouView` 内に組み込むことでファイルを削減。

**新規ファイル**:
- `Modules/LabelStore.swift`
- `Modules/LabelStoreRepository.swift`
- `Modules/ArticleContentFetcher.swift`
- `Modules/LabelingService.swift`
- `Pages/ForYouView.swift`（スコアリングロジックを含む）

**変更ファイル**: `FeedItem.swift`, `ContentView.swift`, `FeedViewModel.swift`

- ✅ Option B より1ファイル少ない
- ✅ ForYouView の責務範囲でスコアリングが収まる規模
- ⚠️ スコアリングが複雑化した場合は分離が必要

**評価**: 代替案として有効

---

## 4. 実装複雑度 & リスク評価

| 機能領域 | 工数 | リスク | 理由 |
|---|---|---|---|
| LabelStoreRepository | S | Low | HistoryStoreRepository と同一パターン |
| ArticleContentFetcher | S | Low | URLSession の既存パターン流用 |
| LabelingService (Ollama HTTP) | M | Medium | Ollama API の仕様把握・プロンプト設計が必要 |
| バックグラウンドラベリング | M | Medium | TaskGroup のライフサイクル管理 |
| For You スコアリング | M | Medium | スコアリングアルゴリズムの設計判断 |
| ForYouView | S | Low | RssCardView 再利用可能、HistoryView が参考 |
| ContentView タブ追加 | S | Low | TabView への単純追加 |
| **合計** | **L** | **Medium** | 外部依存（Ollama）のセットアップがユーザー負担 |

---

## 5. Research Needed（設計フェーズへ持ち越し）

1. **Ollama API 仕様**: エンドポイント・リクエスト形式・レスポンス形式の確認（`/api/generate` vs `/api/chat`）
2. **ラベリングプロンプト設計**: ラベルセットを確実に返させるプロンプトの設計
3. **HTMLテキスト抽出**: `XMLParser` 流用 vs 正規表現 vs 別アプローチ
4. **UserDefaults 容量制限**: 多数記事のラベルデータがUserDefaultsに収まるか（記事数 × URL + ラベル文字列）
5. **スコアリングアルゴリズム**: 単純頻度カウント vs 時間減衰（直近閲覧を重視）の選択

---

## 6. 推奨アプローチと設計フェーズへの引き渡し

**推奨: Option B（完全新規コンポーネント群）**

理由: Ollama HTTP連携・HTMLコンテンツ取得・スコアリングは明確に独立した責務であり、FeedViewModelへの混入はアーキテクチャを損なう。既存の `HistoryStoreRepository` パターンが完全に流用可能で、新規ファイル6本は少ない追加コストで保守性を高める。

**設計フェーズで決定すべき主要事項**:
1. Ollama のモデル選択とプロンプト設計
2. HTML取得テキストの前処理方法
3. スコアリングアルゴリズムの具体的な実装
4. ラベリング失敗時のUXフロー（通知するか、サイレントにスキップするか）
