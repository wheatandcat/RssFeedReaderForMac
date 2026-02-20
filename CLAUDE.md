# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

macOS向けRSSフィードリーダーアプリ。SwiftUI + Xcodeプロジェクト。
RSS 2.0とAtomフィードの両方に対応し、フィードごとに表示件数制限・日数制限・表示ON/OFFを設定可能。

## ビルド・開発コマンド

```bash
# コード整形
swiftformat RssFeedReader/

# Xcodeでビルド（CLI）
xcodebuild -project RssFeedReader/RssFeedReader.xcodeproj -scheme RssFeedReader build

# テスト実行
xcodebuild -project RssFeedReader/RssFeedReader.xcodeproj -scheme RssFeedReader test
```

基本的にはXcodeで開発する（`open RssFeedReader/RssFeedReader.xcodeproj`）。

## アーキテクチャ

```
RssFeedReader/RssFeedReader/
├── RssFeedReaderApp.swift   # @main エントリーポイント
├── ContentView.swift        # TabView（Rss / Config タブ）
├── Modules/                 # モデル・ロジック層
│   ├── Feed.swift           # フィード設定モデル（URL, limit, pubDateLimitDay, show）
│   ├── FeedItem.swift       # パース済み記事モデル
│   ├── FeedViewModel.swift  # メインViewModel（フィード取得・永続化・既読管理）
│   ├── UnifiedFeedParser.swift  # RSS/Atom自動判別パーサー
│   ├── RSSParser.swift      # RSS 2.0パーサー
│   ├── AtomParser.swift     # Atomパーサー
│   └── SeenStore.swift      # 既読管理（SeenStore + SeenStoreRepository）
└── Pages/                   # UI層
    ├── RssView.swift        # フィード一覧（2列LazyVGrid）
    ├── RssCardView.swift    # 記事カード
    └── SettingView.swift    # フィード管理（追加/削除/表示切替）
```

### データフロー

- `FeedViewModel`が`@Published`で`feeds`と`itemsByFeedURL`を管理
- `feeds`の永続化は`UserDefaults`（キー: `feeds.v1`）、JSONエンコード/デコード
- 既読状態は`SeenStore`で`UserDefaults`（キー: `seen-store.v1`）に保存
- フィード取得は`withTaskGroup`で並行実行
- `ContentView`から`RssView`と`SettingView`にViewModelを渡す
