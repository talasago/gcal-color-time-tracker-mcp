WIP

# Google Calendar 色別時間集計MCPサーバー

mcp-rbフレームワークを使用したGoogleカレンダーの色別時間集計MCPサーバーです。

## 機能

- **色別時間集計**: 指定期間のカレンダーイベントを色毎に時間集計
- **参加イベントのみ集計**: 承諾したイベント、主催イベント、プライベートイベントのみ分析対象
- **色フィルタリング**: 特定の色のみを集計対象にしたり、特定の色を除外したりが可能
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

### MCPツール使用例

#### カレンダー分析（参加イベントのみ）

基本的な使用例：
```json
{
  "name": "analyze_calendar",
  "arguments": {
    "start_date": "2024-07-01",
    "end_date": "2024-07-07"
  }
}
```

色フィルタリング使用例：
```json
{
  "name": "analyze_calendar", 
  "arguments": {
    "start_date": "2024-07-01",
    "end_date": "2024-07-07",
    "include_colors": ["緑", "青", 1, "オレンジ"],
    "exclude_colors": ["灰色", 11]
  }
}
```

**分析対象となるイベント：**
- ユーザーが主催者のイベント
- 招待を承諾したイベント（`responseStatus: "accepted"`）
- 参加者情報のないプライベートイベント

**除外されるイベント：**
- 辞退したイベント（`responseStatus: "declined"`）
- 仮承諾のイベント（`responseStatus: "tentative"`）
- 未応答のイベント（`responseStatus: "needsAction"`）

**色フィルタリングパラメータ：**
- `include_colors`: 集計対象の色（色ID(1-11)またはカラー名）
- `exclude_colors`: 集計除外の色（色ID(1-11)またはカラー名）
- 色IDとカラー名の混在指定可能
- exclude_colorsがinclude_colorsより優先

#### 認証開始

```json
{
  "name": "start_auth",
}
```

#### 認証状態確認

```json
{
  "name": "check_auth_status",
}
```

### リソース参照
- **カレンダー色定義**: `calendar://colors`

## プロジェクト構成

```
calendar-color-mcp/
├── lib/
│   ├── calendar_color_mcp.rb            # メインエントリーポイント
│   └── calendar_color_mcp/
│       ├── server.rb                    # MCPサーバー実装
│       ├── google_calendar_client.rb    # Google Calendar API
│       ├── google_calendar_auth_manager.rb # OAuth認証管理
│       ├── token_manager.rb             # トークン保存・管理
│       ├── time_analyzer.rb             # 時間分析ロジック
│       ├── color_filter_manager.rb      # 色フィルタリング
│       └── tools/                       # MCPツール実装
│           ├── base_tool.rb             # ベースツールクラス
│           ├── analyze_calendar_tool.rb # カレンダー分析ツール
│           ├── start_auth_tool.rb       # 認証開始ツール
│           ├── check_auth_status_tool.rb# 認証状態確認ツール
│           └── complete_auth_tool.rb    # 認証完了ツール
├── bin/
│   └── calendar-color-mcp               # 実行可能ファイル
├── spec/                                # テストスイート
├── Gemfile                              # 依存関係定義
├── .env.example                         # 環境変数サンプル
├── CLAUDE.md                            # Claude Code用のサンプル
└── README.md                            # このファイル
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
4. 認証情報は暗号化されてローカルファイルに保存???
5. リフレッシュトークンにより再認証頻度を最小化

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
