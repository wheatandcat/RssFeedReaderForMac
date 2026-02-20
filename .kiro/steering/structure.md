# Project Structure

## Organization Philosophy

機能層で分類する **レイヤー型** 構成。`Modules/` にビジネスロジックを集約し、`Pages/` に画面単位のViewを配置する。

## Directory Patterns

### App Entry
**Location**: `RssFeedReader/RssFeedReader/`
**Purpose**: エントリポイントとルートView
**Example**: `RssFeedReaderApp.swift`（`@main`）、`ContentView.swift`（TabView ルート）

### Modules（ビジネスロジック層）
**Location**: `RssFeedReader/RssFeedReader/Modules/`
**Purpose**: モデル、ViewModel、パーサー、Repository など UI に依存しないロジック
**Pattern**: モデル（`Feed`, `FeedItem`, `SeenStore`）、ViewModel（`FeedViewModel`）、Parser（`UnifiedFeedParser`, `RSSParser`, `AtomParser`）、Repository（`SeenStoreRepository`）

### Pages（画面層）
**Location**: `RssFeedReader/RssFeedReader/Pages/`
**Purpose**: 画面単位のSwiftUIビュー。ViewModelから受け取ったデータを表示する
**Pattern**: `RssView`（記事一覧）、`SettingView`（フィード設定）、`RssCardView`（カードコンポーネント）

## Naming Conventions

- **Views**: PascalCase + `View` サフィックス（例: `RssView`, `RssCardView`）
- **ViewModels**: PascalCase + `ViewModel` サフィックス（例: `FeedViewModel`）
- **Models**: PascalCase 名詞（例: `Feed`, `FeedItem`, `SeenStore`）
- **Parsers**: PascalCase + `Parser` サフィックス（例: `RSSParser`, `AtomParser`）
- **Repositories**: PascalCase + `Repository` サフィックス（例: `SeenStoreRepository`）

## Code Organization Principles

- **単方向データフロー**: `ContentView` が `FeedViewModel` を所有し、子Viewへデータと非同期コールバックを渡す
- **Viewはロジックを持たない**: ネットワーク処理・パース・永続化はすべて `Modules/` に置く
- **`#Preview` 必須**: 各Viewファイルの末尾に `#Preview` を記述してプレビューを保証する

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_
