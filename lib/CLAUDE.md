# Calendar Color MCP Library Documentation

## アーキテクチャ概要

これは、公式**Ruby SDK**で構築された**MCP (Model Context Protocol) サーバー**で、Googleカレンダーの色ベース時間分析を提供します。アーキテクチャは**Clean Architecture**パターンに基づき、関心の分離を明確にしたモジュラー設計に従っています：

### 階層構造（Clean Architecture）

#### 1. サーバー層
- **`CalendarColorMCP::Server`** (lib/calendar_color_mcp/server.rb): `MCP::Server`と`StdioTransport`を使用するメインMCPサーバークラス、ツール登録とリクエストルーティングを処理

#### 2. Interface Adapters層 (lib/calendar_color_mcp/interface_adapters/)
- **Tools**: MCPプロトコルインターフェース実装
  - `AnalyzeCalendarTool`: カレンダー分析ツール
  - `StartAuthTool`: 認証開始ツール
  - `CheckAuthStatusTool`: 認証状態確認ツール
  - `CompleteAuthTool`: 認証完了ツール
  - `BaseTool`: 全ツールの共通基底クラス
- **Presenters**: データ表示形式変換
  - `CalendarAnalysisPresenter`: 分析結果表示形式変換

#### 3. Application層 (lib/calendar_color_mcp/application/)
- **Use Cases**: ビジネスユースケース
  - `AnalyzeCalendarUseCase`: カレンダー分析ユースケース
  - `AuthenticateUserUseCase`: ユーザー認証ユースケース

#### 4. Domain層 (lib/calendar_color_mcp/domain/)
- **Entities**: ビジネスエンティティ
  - `CalendarEvent`: カレンダーイベント
  - `Attendee`: 参加者
  - `Organizer`: 主催者
  - `ColorConstants`: 色定数
- **Services**: ドメインサービス
  - `TimeAnalysisService`: 時間分析サービス
  - `EventFilterService`: イベントフィルタリングサービス

#### 5. Infrastructure層 (lib/calendar_color_mcp/infrastructure/)
- **Repositories**: データアクセス
  - `GoogleCalendarRepository`: Google Calendar API連携
  - `TokenRepository`: 認証トークン管理
- **Services**: 外部サービス連携
  - `GoogleOAuthService`: Google OAuth実装
  - `ConfigurationService`: 設定管理

### MCPツールの仕様

サーバーはMCPプロトコル経由で**4つのツール**を公開（クラスベースツールとして実装）：
- `AnalyzeCalendarTool`: メイン分析ツール（start_date、end_dateが必須） - **オプションの色フィルタリング付きで参加済みイベントのみ分析**
- `StartAuthTool`: シングルユーザー用OAuthフロー開始  
- `CheckAuthStatusTool`: 認証状態検証
- `CompleteAuthTool`: 認証完了処理

**イベントフィルタリング**: 分析には以下の条件のイベントのみ含める：
- ユーザーが主催者（自動的に参加済みとみなす）
- ユーザーが招待を承諾（`responseStatus: "accepted"`）
- 参加者情報のないイベント（プライベートイベント）

`declined`、`tentative`、`needsAction`の応答状態のイベントは分析から除外されます。

**色フィルタリング**: 細かい色ベースフィルタリング用オプションパラメータ：
- `include_colors`: 色ID（1-11）または色名の配列（例：["緑", "青", 1, "オレンジ"]）
- `exclude_colors`: 分析から除外する色IDまたは色名の配列
- 混合フォーマット対応: 色IDと日本語色名を併用可能
- includeとexcludeの両方が指定された場合、excludeが優先

### 認証フロー

**シングルファイルトークン保存**を使用：
- `TokenRepository`がローカルファイルでOAuthトークンを管理
- リフレッシュ機能付きトークン管理
- データベース依存なし - 純粋にローカルファイル管理
- 簡素化された認証のためのシングルユーザー設計

### 主要設計パターン

- **Clean Architecture**: 依存関係は内側の層へのみ向かう設計
- **Use Cases中心設計**: アプリケーションのビジネスロジックをUse Casesに集約
- **Repository パターン**: データアクセスを抽象化し、インフラ層に隔離
- **Presenter パターン**: データ表示形式を責務分離
- **公式MCP SDK統合**: コマンドラインMCPサーバー用に`StdioTransport`付き公式`mcp`gemを使用
- **クラスベースツールアーキテクチャ**: 各MCPツールを`MCP::Tool`を継承する別クラスとして実装
- **Domain Services**: 複数エンティティにまたがるビジネスロジックをサービスクラスに分離
- **OAuth 2.0 OOB（帯域外）フロー**: ローカルウェブサーバーなしのCLIフレンドリー認証
- **エラー境界処理**: 各層で適切なエラー境界を設定し、Google API認証エラーをキャッチして再認証フローをトリガー
- **色ベース集約**: Googleカレンダー色ID（1-11）による日本語色名付きイベントグループ化
- **参加済みイベントフィルタリング**: 認証ユーザーが参加済みのイベントのみ分析（承諾招待、主催イベント、プライベートイベント）
- **色ベースフィルタリング**: IDまたは日本語色名による特定色の包含/除外サポート

## 開発の進め方
### ルール
- unlessとelseを同時に使用しない。
　- その場合はifとelseを使用する。
　- unlessは否定の条件を表すため、elseと組み合わせるとコードの可読性が低下し、認知負荷が増加するため。
### twada氏のTDDにしたがった実装の開発
- まずは失敗するテストを書き、その後にテストを通過するための最小限の実装を行う
- テストが通過したら、リファクタリングを行い、テストが通過することを確認する