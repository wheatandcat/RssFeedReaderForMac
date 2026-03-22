# Requirements Document

## Project Description (Input)
Issue #11: Local LLMで閲覧した記事のデータをラベリングさせる

### 概要
- 閲覧した記事をラベリングしてローカルに保存する機能を実装
- 最終的にはRSSで表示している記事を非同期でラベリングして、「For You」タブを追加しておすすめの記事を紹介してくれるようにしたい

### 対応内容
- 閲覧した記事のURLの中身を読み込んで、以下程度の粒度でラベリング（backend, frontend, sre, AI, go, react, etc.）
- ラベリングにはローカルLLMなど無料で利用できるもので実装
- RSSで記事一覧から記事のラベリングを取得して保存（非同期で取得 & 保存）
- 「For You」のタブを追加して閲覧履歴から最近読んだ記事のラベリングを取得して、RSS一覧からおすすめの記事を紹介する

---

## Introduction

本機能は、macOS向けRSSフィードリーダーアプリに「記事ラベリング」と「パーソナライズドおすすめ」機能を追加するものである。ローカルLLM（Ollama等）を利用して記事コンテンツを技術カテゴリにラベリングし、閲覧履歴をもとにユーザーへ最適な記事を「For You」タブで提示する。ラベリング処理は非同期で行い、通常のRSS閲覧体験を妨げない設計とする。

---

## Requirements

### Requirement 1: 記事コンテンツ取得

**Objective:** RSS閲覧ユーザーとして、記事URLのコンテンツを自動取得させたい。それにより、ラベリングに必要なテキスト情報を準備できる。

#### Acceptance Criteria
1. When RSS記事一覧が表示される, the RSSフィードリーダー shall 各記事のURLに対してHTTPリクエストを発行し本文テキストを取得する
2. When 記事コンテンツの取得が完了する, the RSSフィードリーダー shall タイトル・本文・メタ情報を含むテキストをラベリング処理に渡す
3. If 記事URLへのHTTPリクエストが失敗する, the RSSフィードリーダー shall エラーをログに記録し、当該記事のラベリングをスキップして他の処理を継続する
4. While コンテンツ取得処理が実行中である, the RSSフィードリーダー shall 通常のRSS記事一覧表示をブロックしない
5. The RSSフィードリーダー shall コンテンツ取得リクエストはバックグラウンドタスクとして非同期で実行する

### Requirement 2: ローカルLLMによる記事ラベリング

**Objective:** RSS閲覧ユーザーとして、記事コンテンツをローカルLLMで自動ラベリングさせたい。それにより、無料かつプライバシーを保ちながら記事カテゴリを自動判定できる。

#### Acceptance Criteria
1. When 記事コンテンツのテキストが準備できる, the ラベリングサービス shall ローカルLLM（Ollama等のローカルHTTP API）へ分類リクエストを送信する
2. When ローカルLLMからラベリング結果が返却される, the ラベリングサービス shall 定義済みラベルセット（backend, frontend, sre, cre, db, mysql, postgres, orm, web, react, vue, next, css, graphql, gRPC, go, ruby, rails, マネージング, チームビルディング, AI, cloudflare, GCP, AWS, claude code, cursor, codex, github, CI/CD）から1件以上のラベルを選択して記事に付与する
3. If ローカルLLMサービスが起動していない, the ラベリングサービス shall エラーをログに記録し、ラベリングなしで処理を継続する
4. If ローカルLLMが定義済みラベルセット外の値を返す, the ラベリングサービス shall 当該ラベルを無視し、マッチしたラベルのみを採用する
5. The ラベリングサービス shall 1記事あたり複数のラベルを付与できる

### Requirement 3: ラベリング結果の永続化

**Objective:** RSS閲覧ユーザーとして、ラベリング結果をローカルに保存したい。それにより、アプリ再起動後もラベル情報を維持できる。

#### Acceptance Criteria
1. When ラベリング処理が完了する, the RSSフィードリーダー shall 記事URL・付与ラベル・ラベリング日時をUserDefaultsにJSON形式で永続化する
2. When 同一URLの記事が再度ラベリングされる, the RSSフィードリーダー shall 既存のラベリング結果を上書き更新する
3. The RSSフィードリーダー shall ラベルデータはバージョン付きキー（例: `"article-labels.v1"`）でUserDefaultsに保存する
4. The RSSフィードリーダー shall LabelStoreRepositoryクラスがラベルデータのload/saveを担当する
5. While アプリが起動中である, the RSSフィードリーダー shall 永続化済みラベルデータをメモリにキャッシュして高速アクセスを可能にする

### Requirement 4: 非同期バックグラウンドラベリング

**Objective:** RSS閲覧ユーザーとして、ラベリング処理がバックグラウンドで自動実行されることを期待する。それにより、通常のフィード閲覧体験が妨げられない。

#### Acceptance Criteria
1. When RSS記事一覧の取得が完了する, the RSSフィードリーダー shall 未ラベリングの記事に対してバックグラウンドでラベリングタスクを起動する
2. While ラベリングタスクが実行中である, the RSSフィードリーダー shall 記事一覧のスクロール・タップなどUI操作を妨げない
3. When ラベリングが完了し結果が保存される, the RSSフィードリーダー shall UIを再描画せずにデータのみを更新する
4. The RSSフィードリーダー shall 既にラベリング済みの記事は再度ラベリング処理を実行しない
5. The RSSフィードリーダー shall Swift Concurrency（async/await・TaskGroup）を用いて並行ラベリングを実行する

### Requirement 5: For You タブ

**Objective:** RSS閲覧ユーザーとして、「For You」タブで自分の興味に合ったおすすめ記事を確認したい。それにより、膨大なフィードから関心度の高い記事を効率よく発見できる。

#### Acceptance Criteria
1. When アプリが起動する, the RSSフィードリーダー shall ContentViewのTabViewに「For You」タブを表示する
2. When 「For You」タブが選択される, the RSSフィードリーダー shall 最近閲覧した記事のラベル集計結果に基づき、同ラベルを持つ未閲覧記事を降順スコアでリスト表示する
3. When 閲覧履歴が存在しない, the RSSフィードリーダー shall 「おすすめ記事はまだありません。記事を読むと表示されます。」といったガイダンスメッセージを表示する
4. When おすすめ記事をタップする, the RSSフィードリーダー shall 当該記事URLをブラウザで開き、閲覧済みとして記録する
5. The RSSフィードリーダー shall おすすめスコアは直近30日以内に閲覧した記事のラベル出現頻度をもとに算出する
6. The RSSフィードリーダー shall For Youタブの記事カードは既存のRssCardViewコンポーネントを再利用する

### Requirement 6: ラベル表示（オプション）

**Objective:** RSS閲覧ユーザーとして、記事カードにラベルを表示させたい。それにより、記事の技術カテゴリを一目で把握できる。

#### Acceptance Criteria
1. Where 記事にラベルが付与されている, the RSSフィードリーダー shall 記事カードにラベルをバッジ形式で表示する
2. Where 記事のラベルが未取得である, the RSSフィードリーダー shall ラベルバッジを表示せずカードレイアウトを変更しない
3. The RSSフィードリーダー shall 表示するラベルは最大3件とし、超過分は省略する
