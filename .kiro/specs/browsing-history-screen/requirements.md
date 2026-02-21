# Requirements Document

## Project Description (Input)
RssFeedReaderのMacアプリに閲覧履歴を表示する画面を作成

## Introduction

RssFeedReader macOSアプリに、ユーザーが過去に閲覧したRSS記事の履歴を確認できる専用画面を追加する。既存の `SeenStore` が既読記事IDを管理しているが、現在は閲覧日時・記事タイトル・URLを遡って確認する手段がない。本機能では閲覧履歴をタイムスタンプ付きで記録・表示し、ユーザーが読み返したい記事を素早く発見できるようにする。

---

## Requirements

### Requirement 1: 閲覧履歴の記録

**Objective:** As a ユーザー, I want 記事を開いたときに閲覧履歴が自動的に記録される, so that 後から読んだ記事を遡って確認できる

#### Acceptance Criteria

1. When ユーザーがRSSカードをクリックして記事URLを開いたとき, the RSS Feed Reader shall 記事のID・タイトル・URL・フィード名・閲覧日時をHistoryStoreに保存する
2. The RSS Feed Reader shall 閲覧日時をISO 8601形式のタイムスタンプとして記録する
3. When 同一記事が複数回閲覧されたとき, the RSS Feed Reader shall 最新の閲覧日時で既存エントリを上書き更新する（重複記録しない）
4. The RSS Feed Reader shall 閲覧履歴をUserDefaultsに `"history-store.v1"` キーでJSONシリアライズして永続化する
5. The RSS Feed Reader shall 最大保存件数を500件とし、超過した場合は古いエントリから削除する

---

### Requirement 2: 閲覧履歴一覧の表示

**Objective:** As a ユーザー, I want 閲覧履歴画面で過去に読んだ記事の一覧を見る, so that 再度読みたい記事をすぐに見つけられる

#### Acceptance Criteria

1. The RSS Feed Reader shall 閲覧履歴画面（HistoryView）に履歴エントリを閲覧日時の降順（新しい順）でリスト表示する
2. When 閲覧履歴が0件のとき, the RSS Feed Reader shall 「閲覧履歴はありません」というメッセージを画面中央に表示する
3. The RSS Feed Reader shall 各履歴エントリに記事タイトル・フィード名・閲覧日時を表示する
4. The RSS Feed Reader shall 閲覧日時を「YYYY/MM/DD HH:mm」形式で表示する
5. While 閲覧履歴が読み込み中のとき, the RSS Feed Reader shall ローディングインジケーターを表示する

---

### Requirement 3: 閲覧履歴からの記事アクセス

**Objective:** As a ユーザー, I want 履歴一覧から記事を直接開く, so that 再閲覧の操作が最小限で済む

#### Acceptance Criteria

1. When ユーザーが履歴エントリをクリックしたとき, the RSS Feed Reader shall 対応する記事URLをデフォルトブラウザで開く
2. When ユーザーが履歴エントリをクリックしたとき, the RSS Feed Reader shall 閲覧日時を現在時刻で更新して履歴先頭に移動する
3. If 記事URLが無効または空のとき, the RSS Feed Reader shall エントリをクリック不可として表示する

---

### Requirement 4: 閲覧履歴のナビゲーション統合

**Objective:** As a ユーザー, I want アプリのメインナビゲーションから閲覧履歴画面に遷移する, so that 既存ワークフローを中断せずに履歴を確認できる

#### Acceptance Criteria

1. The RSS Feed Reader shall 既存のTabViewに「履歴」タブを追加し、HistoryViewを表示する
2. The RSS Feed Reader shall 「履歴」タブのアイコンにSF Symbolsの `clock` を使用する
3. When ユーザーが「履歴」タブに切り替えたとき, the RSS Feed Reader shall 最新の閲覧履歴データを表示する

---

### Requirement 5: 閲覧履歴の削除

**Objective:** As a ユーザー, I want 閲覧履歴を削除する, so that プライバシーを管理できる

#### Acceptance Criteria

1. The RSS Feed Reader shall 閲覧履歴画面に「すべて削除」ボタンを提供する
2. When ユーザーが「すべて削除」をクリックしたとき, the RSS Feed Reader shall 確認ダイアログを表示してから全履歴を削除する
3. When ユーザーが個別エントリを右クリックしたとき, the RSS Feed Reader shall コンテキストメニューに「この履歴を削除」を表示する
4. When ユーザーが「この履歴を削除」を選択したとき, the RSS Feed Reader shall 該当エントリのみをHistoryStoreから削除し画面を更新する
5. If 全履歴削除後にUserDefaultsを確認したとき, the RSS Feed Reader shall `"history-store.v1"` キーが空配列状態で保存されている
