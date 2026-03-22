# Rssリーダー

## 起動方法

### 1. アプリのビルド・起動

Xcode でプロジェクトを開いてビルド・実行する。

```
open RssFeedReader.xcodeproj
```

### 2. For You 機能（ローカルLLMラベリング）の準備

For You タブでのおすすめ記事表示には **Ollama** が必要。

#### Ollama のインストール

```bash
brew install ollama
```

または https://ollama.com からインストーラーをダウンロード。

#### モデルのダウンロード

```bash
ollama pull llama3.2:3b
```

#### Ollama の起動

```bash
ollama serve
```

`http://localhost:11434` で起動していることを確認。

### 3. 動作フロー

1. アプリを起動し、RSS タブで「更新」ボタンを押す
2. フィード取得完了後、バックグラウンドで各記事の本文を取得し Ollama でラベリングが自動実行される
3. ラベリング結果は UserDefaults に永続化されるため、次回起動時は再ラベリングしない
4. **For You** タブを開くと、閲覧履歴のラベル頻度に基づいたおすすめ記事が表示される

> **Note**: Ollama が未起動の場合、ラベリングはスキップされる（アプリは正常動作する）。For You タブには記事が表示されないか、ラベリング済みの過去データのみ表示される。

## コード整形

```bash
$ swiftformat .
```
