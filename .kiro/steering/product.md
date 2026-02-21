# Product Overview

macOS向けのRSSフィードリーダーアプリ。複数のRSS/Atomフィードを一元管理し、最新記事をカード形式で閲覧できる。

## Core Capabilities

- **マルチフィード管理**: RSS 2.0 / Atom フィードを複数登録・削除・表示切替
- **記事カード表示**: サムネイル・サイトアイコン・公開日付きの2列グリッドカードUI
- **新着トラッキング**: 既読IDをUserDefaultsに永続化し、未読記事に「NEW」バッジを表示
- **フィルタリング**: 記事数上限（limit）と公開日期間制限（pubDateLimitDay）でフィード毎に制御

## Target Use Cases

- 技術ブログ・ポッドキャスト・ニュースサイトを横断して一覧確認したい開発者
- macOS Menubar / デスクトップで手軽にフィードをチェックしたいユーザー

## Value Proposition

複数フィードを並行取得し、日付ソート・既読管理・サムネイル表示をシンプルなSwiftUI UIで提供。外部サービス依存なく、UserDefaultsのみで動作。

---
_Focus on patterns and purpose, not exhaustive feature lists_
