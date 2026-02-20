# Research & Design Decisions

---
**Purpose**: 閲覧履歴画面機能のディスカバリー結果・設計判断の記録。

---

## Summary
- **Feature**: `browsing-history-screen`
- **Discovery Scope**: Extension（既存macOSアプリへの画面追加）
- **Key Findings**:
  - `SeenStoreRepository` が UserDefaults + JSONEncoder/Decoder パターンを確立済み。`HistoryStoreRepository` は同パターンをそのまま踏襲する。
  - `ContentView` の `enum tab` に `.history` を追加するだけで TabView 統合が完了する（最小変更）。
  - `FeedViewModel` に履歴操作メソッドを追加し、子View（`RssView`）へ `onOpen` コールバックとして渡すことで既存の props drilling パターンを維持できる。

---

## Research Log

### 既存 SeenStore / Repository パターン分析
- **Context**: `HistoryStore` / `HistoryStoreRepository` の設計方針を決めるため
- **Sources Consulted**: `Modules/SeenStore.swift`, `Modules/FeedViewModel.swift`
- **Findings**:
  - `SeenStore` は `Codable` 構造体 + `SeenStoreRepository` (load/save) の分離パターン
  - UserDefaults キーは `"seen-store.v1"` の形式でバージョン付き
  - `FeedViewModel` が `private let seenRepo = SeenStoreRepository()` として所有し、ロード・セーブを呼び出す
- **Implications**: `HistoryStore` / `HistoryStoreRepository` / `FeedViewModel` 拡張を同じ構造で実装すれば既存コードベースと完全に一致する

### ContentView タブ統合分析
- **Context**: 新しいタブを追加する影響範囲の確認
- **Sources Consulted**: `ContentView.swift`
- **Findings**:
  - `enum tab: Hashable { case rss; case config }` — 追加は `.history` ケースのみ
  - `@StateObject private var vm = FeedViewModel()` を `HistoryView` にも渡す形が最も自然
  - `HistoryView` へ渡す引数は `historyEntries`・`onOpen`・`onDelete`・`onClearAll` の callback 群
- **Implications**: `ContentView.swift` の変更は最小限（`enum` に1ケース、TabView に1エントリ）

### RssView の記事オープンフロー分析
- **Context**: 記事クリック時に履歴を記録するフックポイントの特定
- **Sources Consulted**: `Pages/RssView.swift`, `Pages/RssCardView.swift`
- **Findings**:
  - `RssView` は `let reload: () async -> Void` のように非同期コールバックを受け取るパターン
  - `RssCardView` の `onTap: () -> Void` が `RssView` 内で `openURL(url)` として実装されている
  - 現在、記事タップ時に `HistoryEntry` を記録する処理は存在しない
- **Implications**: `RssView` に `onOpen: (FeedItem) -> Void` コールバックを追加し、カードタップ時に `openURL` + `onOpen` を同時に呼ぶよう変更する。`ContentView` 側で `vm.recordHistory(_:)` をこのコールバックに接続する。

### FeedItem モデル分析
- **Context**: HistoryEntry に必要なフィールドが FeedItem から取得できるか確認
- **Sources Consulted**: `Modules/FeedItem.swift`
- **Findings**:
  - `stableID: String` — 重複検出・更新に使用可能
  - `title: String`, `link: String`, `siteTitle: String`, `sourceFeedURL: String` — 履歴表示に必要な情報がすべて揃っている
- **Implications**: `HistoryEntry` は `FeedItem` から直接初期化でき、変換レイヤーは不要

---

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Repository パターン（採用）| `HistoryStoreRepository` で load/save を担当し、ViewModel が呼び出す | 既存 SeenStoreRepository と完全に対称。テスト可能 | なし | steering tech.md に明記された推奨パターン |
| ViewModel に直接永続化 | ViewModel 内に UserDefaults 操作を直接記述 | コード量削減 | 責務が混在、テスト困難 | 不採用 |
| 専用 HistoryViewModel | 新しい ObservableObject を作成 | 分離が明確 | FeedViewModel との状態共有が必要になり複雑化 | 不採用。既存の FeedViewModel に統合する方が一貫性が高い |

---

## Design Decisions

### Decision: `HistoryEntry` を FeedItem から独立した値型として定義する
- **Context**: 履歴エントリはフィード再取得後も残る必要があり、FeedItem はメモリ上の一時データ
- **Alternatives Considered**:
  1. `FeedItem` をそのまま Codable 化して保存
  2. 独立した `HistoryEntry` 構造体を定義
- **Selected Approach**: `HistoryEntry: Codable, Identifiable` を独立定義し、`stableID`, `title`, `link`, `feedName`, `viewedAt: Date` を保持する
- **Rationale**: `FeedItem` は `thumbnailURL` 等の一時的なフィールドを持ち Codable でない。履歴は永続化が必要なため最小限のフィールドを持つ専用型が適切
- **Trade-offs**: `FeedItem` からの変換コードが必要になるが、軽微
- **Follow-up**: `FeedItem.stableID` が空の場合は `link` をフォールバックとして使用（FeedViewModel 既存ロジックと同様）

### Decision: 履歴管理を FeedViewModel に統合する
- **Context**: 専用 HistoryViewModel vs FeedViewModel 拡張
- **Alternatives Considered**:
  1. 専用 `HistoryViewModel: ObservableObject` を `ContentView` で `@StateObject` として保有
  2. `FeedViewModel` に履歴プロパティとメソッドを追加
- **Selected Approach**: `FeedViewModel` に `@Published var historyEntries: [HistoryEntry]` と操作メソッドを追加
- **Rationale**: アプリのデータ規模が小さく、`ContentView` が管理する ViewModel は1つにとどめる方が props drilling 構造がシンプルになる。steering tech.md の「Root ViewにのみViewModelを@StateObjectで生成する」原則に従う
- **Trade-offs**: FeedViewModel がやや肥大化するが、機能の凝集度は保たれる

### Decision: 最大件数 500 件で古い順に削除する
- **Context**: UserDefaults の容量制限と検索パフォーマンス
- **Alternatives Considered**:
  1. 件数制限なし
  2. 100件上限
  3. 500件上限
- **Selected Approach**: 500件上限（要件 1.5）。保存時に配列末尾（最古）から超過分を削除
- **Rationale**: UserDefaults は大容量ストレージを想定していない。RSS記事タイトル等のテキストデータで500件は約50-100KB程度で問題ない

---

## Risks & Mitigations
- **UserDefaults 書き込み頻度**: 記事タップごとに save が発生する — 対策: `HistoryStoreRepository.save()` は同期処理で軽量なため許容範囲
- **stableID が空のケース**: FeedItem.stableID が空の場合は link を代替使用（FeedViewModel 既存ロジックを踏襲）
- **RssView の既存コールバック署名変更**: `reload` 以外に `onOpen` を追加するため、既存の `#Preview` も更新が必要

---

## References
- `RssFeedReader/RssFeedReader/Modules/SeenStore.swift` — Repository パターンの参照実装
- `RssFeedReader/RssFeedReader/ContentView.swift` — TabView 統合ポイント
- `RssFeedReader/RssFeedReader/Modules/FeedViewModel.swift` — ViewModel 拡張ターゲット
