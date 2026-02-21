# Technology Stack

## Architecture

MVVM + Repository パターン。`FeedViewModel` が状態を一元管理し、View はデータと callback を受け取る純粋な表示層として機能する。

## Core Technologies

- **Language**: Swift (macOS)
- **Framework**: SwiftUI + Combine
- **Concurrency**: Swift Concurrency（async/await, TaskGroup, @MainActor）
- **Persistence**: UserDefaults（JSONEncoder/Decoder でモデルをシリアライズ）

## Key Libraries

標準ライブラリのみ使用（外部依存なし）:
- `Foundation.URLSession` — フィードのHTTP取得
- `Foundation.XMLParser` / `NSXMLParser` — RSS/Atomパース
- `SwiftUI.AsyncImage` — 非同期画像表示

## Development Standards

### State Management
- ViewModel は `@MainActor final class` + `ObservableObject`
- Root ViewにのみViewModelを`@StateObject`で生成し、子Viewへはプロパティとして渡す（props drilling）
- 子ViewがViewModelを直接参照する場合は `@ObservedObject`（例: `SettingView`）

### Data Persistence
- 全永続化は `UserDefaults` + JSON。キーはバージョン付き（例: `"feeds.v1"`, `"seen-store.v1"`）
- Repository クラスが load/save を担当し、ViewModel はそれを呼ぶ

### Concurrency
- フィード並行取得には `withTaskGroup` を使用
- UI更新は `@MainActor` で保証

### Parsing
- `UnifiedFeedParser` がルート要素名（`<feed>` or `<rss>`）を正規表現で判定し、`AtomParser` / `RSSParser` に振り分ける

## Development Environment

### Required Tools
- Xcode 16+（macOS 14+ ターゲット推奨）

### Common Commands
```bash
# Build/Run: Xcode から直接実行
# Test: Cmd+U（XCTest）
```

## Key Technical Decisions

- **外部依存ゼロ**: Swift Package Manager を使わず標準ライブラリのみ。ビルドシンプル化が目的
- **UserDefaults選択**: Core Data / SQLite 不使用。データ量が少なく複雑なクエリ不要のため

---
_Document standards and patterns, not every dependency_
