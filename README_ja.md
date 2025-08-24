# Calendar Color Time Tracker MCP Server

**English version**→ [README.md](README.md)

Google Calendar色別時間分析のためのMCP (Model Context Protocol) サーバーです。Clean Architectureパターンを採用し、公式MCP Ruby SDKで実装されています。

## 機能

- **色別時間集計**: 指定期間のカレンダーイベントを色毎に時間集計
- **参加イベントのみ集計**: 承諾したイベント、主催イベント、プライベートイベントのみ分析対象
- **色フィルタリング**: 特定の色のみを集計対象にしたり、特定の色を除外したりが可能
- **Clean Architecture**: 保守性と拡張性を重視した設計パターンを採用
- **OAuth 2.0認証**: Google Calendar APIアクセス用のセキュアな認証
- **シングルユーザー対応**: データベース不要のローカルファイル管理

## インストール・セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/talasago/gcal-color-time-tracker-mcp.git
cd gcal-color-time-tracker-mcp
```

### 2. 前提条件

このプロジェクトを実行するには、RubyとBundlerがシステムにインストールされている必要があります。

```bash
# Ruby のインストール（バージョン 3.3.6 以上を推奨）
# macOS で Homebrew を使用する場合：
brew install ruby

# Ubuntu/Debian の場合：
sudo apt-get install ruby-dev

# Windows の場合、RubyInstaller を使用：
# https://rubyinstaller.org/

# Bundler gem のインストール
gem install bundler
```

### 3. 依存関係のインストール

```bash
bundle install
```

### 4. Google Cloud Console設定

#### 4.1. プロジェクトの作成・選択
1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス
2. 新規プロジェクトを作成するか、既存プロジェクトを選択
3. コンソール上部でプロジェクトが正しく選択されていることを確認

#### 4.2. Google Calendar APIの有効化
1. 正しいプロジェクトが選択されていることを確認
2. [Calendar API library page](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)にアクセス
3. 「有効にする」をクリック

#### 4.3. OAuth 2.0 認証情報の作成
1. 左側メニューから「認証情報」を選択
2. 「認証情報を作成」→「OAuth クライアントID」をクリック
3. OAuth同意画面の設定（初回のみ）：
   - 「外部」を選択（組織外ユーザーがアクセス可能）
   - アプリケーション名を入力
   - ユーザーサポートメールを設定
   - 開発者の連絡先情報を入力
   - スコープの追加（オプション）：
     - `https://www.googleapis.com/auth/calendar.events`
     - `https://www.googleapis.com/auth/calendar`
4. アプリケーションの種類で「デスクトップアプリケーション」を選択
5. 名前を入力（例：Calendar Color MCP）
6. 「作成」をクリック

#### 4.4. 認証情報の取得
1. 作成されたOAuthクライアントの「クライアントID」と「クライアントシークレット」をコピー
2. これらの設定を下部のjsonファイルで設定します

#### 4.5. テストユーザーの追加
1. OAuth同意画面設定で「テストユーザー」セクションに移動
2. 「ユーザーを追加」をクリックして、カレンダーにアクセスするGoogleアカウントのメールアドレスを追加
3. ⚠️ **注意**: テストユーザーの追加には数分かかる場合があります

### 5. Claude Desktop設定

Claude Desktop設定ファイル (`claude_desktop_config.json`) で環境変数を設定します。
設定方法は「Claude Desktop での使用例」セクションを参照してください。

### 6. 実行権限付与

```bash
chmod +x bin/calendar-color-mcp
```

## 使用方法

### Claude Desktop での使用例

#### Claude Desktop 設定 (claude_desktop_config.json)

```json
{
  "mcpServers": {
    "calendar-color-mcp": {
      "command": "/path/to/calendar-color-mcp/bin/calendar-color-mcp",
      "env": {
        "GOOGLE_CLIENT_ID": "your_google_client_id",
        "GOOGLE_CLIENT_SECRET": "your_google_client_secret",
        "DEBUG": false
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
    "include_colors": ["Sage", "Peacock", 1, "オレンジ"],
    "exclude_colors": ["Graphite", "Tomato", 11]
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

## プロジェクト構成 (Clean Architecture)

```
calendar-color-mcp/
├── lib/
│   ├── calendar_color_mcp.rb            # メインエントリーポイント
│   └── calendar_color_mcp/
│       ├── server.rb                    # MCPサーバー実装
│       ├── loggable.rb                  # ログ機能
│       ├── logger_manager.rb            # ログ管理
│       ├── interface_adapters/          # Interface Adapters層
│       │   ├── tools/                   # MCPツール実装
│       │   └── presenters/              # データ表示形式変換
│       ├── application/                 # Application層
│       │   └── use_cases/               
│       ├── domain/                      # Domain層
│       │   ├── entities/                
│       │   └── services/                
│       └── infrastructure/              # Infrastructure層
│           ├── repositories/            
│           └── services/                
├── spec/                                # テストスイート (RSpec)
│   ├── CLAUDE.md                        
│   └── [各層に対応したテスト構造]
├── docs/                                # 開発ドキュメント
├── bin/
│   └── calendar-color-mcp               # 実行可能ファイル
├── Gemfile                              # 依存関係定義
├── LICENSE                              
├── CLAUDE.md                            # Claude Code用プロジェクト説明
```

## カレンダー色定義

| 色ID | 英語名 | 日本語名 |
|------|--------|----------|
| 1 | Lavender | 薄紫 |
| 2 | Sage | 緑 |
| 3 | Grape | 紫 |
| 4 | Flamingo | 赤 |
| 5 | Banana | 黄 |
| 6 | Tangerine | オレンジ |
| 7 | Turquoise | 水色 |
| 8 | Graphite | 灰色 |
| 9 | Peacock | 青（デフォルト） |
| 10 | Basil | 濃い緑 |
| 11 | Tomato | 濃い赤 |

色フィルタリングでは、色ID（1-11）、英語名、日本語名のいずれでも指定可能です。

## 認証フロー

1. 初回使用時は認証が必要
2. `start_auth`ツールまたは`analyze_calendar`実行時に認証URLが提供される
3. URLにアクセスしてGoogle認証を完了
4. 認証情報はローカルファイルに保存
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

## アーキテクチャ

このプロジェクトはClean Architectureパターンを採用しています。詳細なアーキテクチャ情報については以下のドキュメントを参照してください：

- **[lib/CLAUDE.md](lib/CLAUDE.md)**: ライブラリアーキテクチャ、設計パターン、ビジネスロジックの詳細
- **[spec/CLAUDE.md](spec/CLAUDE.md)**: テストアーキテクチャ、テストルール、テスト実行方法の詳細

## ライセンス

MIT License
