WIP

# Google Calendar 色別時間集計MCPサーバー

mcp-rbフレームワークを使用したGoogleカレンダーの色別時間集計MCPサーバーです。

## 機能

- **色別時間集計**: 指定期間のカレンダーイベントを色毎に時間集計
- **MCPツール**: `analyze_calendar` ツールで分析実行
- **MCPリソース**: 認証状態やユーザー情報をリソースとして提供
- **複数ユーザー対応**: データベースを使わずにローカルファイルで管理
- **OAuth 2.0認証**: Google Calendar APIアクセス用認証

## インストール・セットアップ

### 1. 依存関係のインストール

```bash
bundle install
```

### 2. Google Cloud Console設定

1. [Google Cloud Console](https://console.cloud.google.com/)でプロジェクトを作成
2. Google Calendar APIを有効化
3. OAuth 2.0認証情報を作成（デスクトップアプリケーション）
4. クライアントIDとクライアントシークレットを取得

### 3. 環境変数設定

```bash
cp .env.example .env
```

`.env`ファイルを編集してGoogle OAuth認証情報を設定：

```bash
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
DEBUG=true
```

### 4. 実行権限付与

```bash
chmod +x bin/calendar-color-mcp
```

## 使用方法

### 通常のセットアップ（ローカル実行）

#### MCPサーバー起動

```bash
./bin/calendar-color-mcp
```

### Claude Desktop での使用例

#### Claude Desktop 設定 (claude_desktop_config.json)

```json
{
  "mcpServers": {
    "calendar-color-mcp": {
      "command": "/path/to/calendar-color-mcp/bin/calendar-color-mcp",
      "env": {
        "GOOGLE_CLIENT_ID": "your_google_client_id",
        "GOOGLE_CLIENT_SECRET": "your_google_client_secret"
      }
    }
  }
}
```

#### Cursor での使用例

#### .cursor-settings.json 設定

```json
{
  "mcp": {
    "servers": {
      "calendar-color-mcp": {
        "command": "/path/to/calendar-color-mcp/bin/calendar-color-mcp",
        "env": {
          "GOOGLE_CLIENT_ID": "your_google_client_id", 
          "GOOGLE_CLIENT_SECRET": "your_google_client_secret"
        }
      }
    }
  }
}
```

### MCPツール使用例

#### カレンダー分析

```json
{
  "name": "analyze_calendar",
  "arguments": {
    "user_id": "tanaka",
    "start_date": "2024-07-01",
    "end_date": "2024-07-07"
  }
}
```

#### 認証開始

```json
{
  "name": "start_auth",
  "arguments": {
    "user_id": "tanaka"
  }
}
```

#### 認証状態確認

```json
{
  "name": "check_auth_status",
  "arguments": {
    "user_id": "tanaka"
  }
}
```

### リソース参照

- **全ユーザーの認証状態**: `auth://users`
- **カレンダー色定義**: `calendar://colors`

## プロジェクト構成

```
calendar-color-mcp/
├── lib/
│   ├── calendar_color_mcp.rb          # メインサーバー
│   ├── calendar_color_mcp/
│   │   ├── server.rb                  # MCPサーバー実装
│   │   ├── google_calendar_client.rb  # Google Calendar API
│   │   ├── time_analyzer.rb           # 時間分析ロジック
│   │   ├── user_manager.rb            # ユーザー管理
│   │   └── auth_manager.rb            # 認証管理
├── bin/
│   └── calendar-color-mcp             # 実行可能ファイル
├── user_tokens/                       # トークン保存
├── Gemfile
├── .env.example
├── calendar_color_mcp.gemspec
└── README.md
```

## カレンダー色定義

| 色ID | 色名 |
|------|------|
| 1 | 薄紫 |
| 2 | 緑 |
| 3 | 紫 |
| 4 | 赤 |
| 5 | 黄 |
| 6 | オレンジ |
| 7 | 水色 |
| 8 | 灰色 |
| 9 | 青（デフォルト） |
| 10 | 濃い緑 |
| 11 | 濃い赤 |

## 認証フロー

1. 初回使用時は認証が必要
2. `start_auth`ツールまたは`analyze_calendar`実行時に認証URLが提供される
3. URLにアクセスしてGoogle認証を完了
4. 認証情報は暗号化されてローカルファイルに保存
5. リフレッシュトークンにより再認証頻度を最小化

## トラブルシューティング

### 認証エラー

- Google Cloud Consoleでカレンダー API が有効化されているか確認
- 環境変数が正しく設定されているか確認
- トークンファイル（`user_tokens/`）を削除して再認証

### 依存関係エラー

```bash
bundle install
```

### 権限エラー

```bash
chmod +x bin/calendar-color-mcp
```

## 開発・テスト

### 開発環境

```bash
bundle install
```

### テスト実行

```bash
bundle exec rspec
```

### デバッグ

環境変数`DEBUG=true`を設定してデバッグログを有効化

## ライセンス

MIT License
