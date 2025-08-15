# アーキテクチャ設計決定書

Calendar Color MCP プロジェクトのアーキテクチャ設計方針と実装指針

---

## 📋 目次

1. [Singletonパターンの妥当性分析](#1-singletonパターンの妥当性分析)
2. [現在のアーキテクチャ課題分析](#2-現在のアーキテクチャ課題分析)
3. [クリーンアーキテクチャ適用指針](#3-クリーンアーキテクチャ適用指針)
4. [改善ロードマップ](#4-改善ロードマップ)

---

## 1. Singletonパターンの妥当性分析

### 1.1 MCPサーバーアーキテクチャでのSingleton適用根拠

#### MCPサーバーの特性
```ruby
# lib/calendar_color_mcp/server.rb
@server = MCP::Server.new(
  server_context: {
    token_manager: @token_manager,    # 全ツールで共有
    auth_manager: @auth_manager       # 全ツールで共有
  }
)
```

MCPサーバーでは以下の特徴があります：
- **単一プロセス内で複数MCPツールが動作**
- **認証状態は全ツール間で共有される必要**
- **トークン管理は一元化が必須**

### 1.2 TokenManagerでのSingleton妥当性

#### ✅ Singletonが適切な理由

**1. ドメイン的妥当性**
```ruby
# token.json ファイルは物理的に単一
TOKEN_FILE = 'token.json'
```
- Google OAuth2トークンは本質的にアプリケーション全体で一意の状態
- 複数のTokenManagerインスタンスは同一ファイルの競合アクセスを引き起こすリスク
- ファイルロックやトランザクション管理の複雑化を回避

**2. リソース保護**
```ruby
def save_credentials(credentials)
  File.write(@token_file_path, token_data.to_json)
end
```
- 同時書き込みアクセスの排他制御
- ファイルI/Oの一元管理による整合性保証

**3. MCPツール間での状態共有**
```ruby
# 全MCPツールで同じ認証状態を参照
StartAuthTool    → token_manager.clear_credentials
CompleteAuthTool → token_manager.save_credentials  
AnalyzeCalendarTool → token_manager.load_credentials
```

#### ⚠️ テスト上の制約（許容範囲）

```ruby
# spec/token_manager_spec.rb
before do
  token_manager.clear_credentials if token_manager.token_exist?
end
```
- テスト間でのクリーンアップが必要
- しかし、実際のドメインロジックテストは正常に動作
- テストの複雑さよりもドメインの整合性を優先

### 1.3 GoogleCalendarAuthManagerでのSingleton妥当性

#### ✅ Singletonが適切な理由

**1. 認証フローの統一性**
```ruby
def get_auth_url
  # OAuth2 URLは同一である必要（複数URL発行は混乱の元）
  "https://accounts.google.com/o/oauth2/auth?#{query_string}"
end
```

**2. 設定の一元管理**
```ruby
ENV['GOOGLE_CLIENT_ID']     # アプリケーション全体で統一
ENV['GOOGLE_CLIENT_SECRET'] # 複数の設定インスタンスは不要
```

**3. 認証状態の一貫性**
```ruby
def token_exist?
  @token_manager.token_exist?  # 全ツールで同じ回答であるべき
end
```

#### テスト影響の軽微さ
```ruby
# spec/google_calendar_auth_manager_spec.rb
it "should return a valid Google OAuth URL" do
  url = auth_manager.get_auth_url
  expect(url).to eq(expected_url)
end
```
- AuthManagerは主に**ステートレスな操作**
- TokenManagerほどテストが複雑化しない
- 環境変数のモック程度で十分

### 1.4 一般的なSingleton批判への反論

#### 批判1: "テスタビリティが低い"
**反論**: 
- 現在のテストスイートは正常に動作
- ドメインの本質（単一認証状態）を正しく表現
- 過度なテスト容易性のためにドメインを歪めるべきでない

#### 批判2: "依存性が隠蔽される"
**反論**:
- MCPサーバー内では依存関係は明示的（server_context経由）
- 外部からの利用時のみSingletonアクセス
- 依存性注入との組み合わせ可能

#### 批判3: "グローバル状態"
**反論**:
- 認証・トークンは本質的にグローバル状態
- 複数インスタンスの存在はむしろ設計上の問題
- アプリケーションの性質上、グローバル状態が適切

---

## 2. 現在のアーキテクチャ課題分析

### 2.1 責任境界の曖昧性

#### 問題1: GoogleCalendarClientの肥大化

```ruby
# lib/calendar_color_mcp/google_calendar_client.rb:22-65 (60行超)
def get_events(start_date, end_date)
  authenticate                    # 認証責任
  
  # API呼び出し責任
  all_events = @service.list_events(...)
  
  # ビジネスロジック責任（フィルタリング）
  attended_events = filter_attended_events(all_events)
  
  # ログ出力責任（デバッグ情報20行）
  logger.debug "=== Google Calendar API Response Debug ==="
  # ...20行のログ出力
  
  attended_events
end
```

**問題点**:
- **単一メソッドに4つの異なる責任**が混在
- 60行を超える巨大メソッド
- テストの困難さ（モックが複雑）

#### 問題2: TimeAnalyzerのログ混入

```ruby
# lib/calendar_color_mcp/time_analyzer.rb:60-96 (36行)
def calculate_duration(event)
  logger.debug "--- Duration Calculation Debug ---"
  logger.debug "Event: #{event.summary}"
  # ...30行以上のデバッグログ
  
  duration = if event.start.date_time && event.end.date_time
    # 実際のビジネスロジックは数行のみ
  end
  
  duration
end
```

**問題点**:
- **ビジネスロジックにデバッグログが過度に混入**
- 本質的な処理が見えにくい
- ログレベル変更時の影響範囲が大きい

### 2.2 エラーハンドリングの不統一

#### 問題1: 例外の握りつぶし

```ruby
# lib/calendar_color_mcp/google_calendar_client.rb:88-90
def get_user_email
  calendar_info = @service.get_calendar('primary')
  calendar_info.id
rescue => e
  # FIXME:例外を握りつぶしていいのか？
  logger.debug "User email retrieval error: #{e.message}"
  nil
end
```

#### 問題2: エラーレスポンス形式の複雑化

```ruby
# lib/calendar_color_mcp/tools/base_tool.rb:44-70
class ErrorResponseBuilder
  def initialize(message)
    @data = { success: false, error: message }
  end
  
  def with(key, value = nil, **data)
    # 複雑なビルダーパターン
  end
end
```

**問題点**:
- シンプルなエラーレスポンスに過度な抽象化
- 統一性のないエラーハンドリング方針

### 2.3 設定管理の重複

#### 環境変数検証の重複実装

```ruby
# lib/calendar_color_mcp/server.rb:55-78
def validate_environment_variables
  missing_vars = []
  if ENV['GOOGLE_CLIENT_ID'].nil? || ENV['GOOGLE_CLIENT_ID'].empty?
    missing_vars << 'GOOGLE_CLIENT_ID'
  end
  # ...
end

# lib/calendar_color_mcp/google_calendar_auth_manager.rb:32-41
def get_auth_url
  if ENV['GOOGLE_CLIENT_ID'].nil? || ENV['GOOGLE_CLIENT_ID'].empty?
    raise "GOOGLE_CLIENT_ID not set. Check .env file."
  end
  # ...
end
```

**問題点**:
- 同一の環境変数チェックロジックが重複
- エラーメッセージの不統一
- 設定変更時の修正箇所の分散

### 2.4 未解決の技術債務（FIXMEコメント）

```ruby
# lib/calendar_color_mcp/server.rb:47
# FIXME: ここで呼び出し失敗時のエラーハンドリングがあってもよさそう

# lib/calendar_color_mcp/google_calendar_client.rb:21  
# FIXME:ビジネスロジックが含まれていることが問題

# lib/calendar_color_mcp/tools/base_tool.rb:27
# TODO: もしかしたらこっちもbuilderパターンの方が良いのかもしれない
```

---

## 3. クリーンアーキテクチャ適用指針

### 3.1 MCPサーバー向け4層レイヤー設計

```
📁 Entities (Domain)              # 最内層
├── CalendarEvent                 # ドメインエンティティ
├── TimeSpan                      # 値オブジェクト  
├── AuthToken                     # 認証情報
└── EventFilter                   # フィルタ条件

📁 Use Cases (Application)        # アプリケーションサービス層
├── AnalyzeCalendarUseCase        # カレンダー分析
├── AuthenticateUserUseCase       # 認証フロー
└── FilterEventsByColorUseCase    # 色別フィルタリング

📁 Interface Adapters            # インターフェース層
├── Controllers/                 
│   └── MCPToolsController       # MCPツール（Presenter）
├── Repositories/
│   ├── GoogleCalendarRepository # API Gateway
│   └── TokenFileRepository      # ファイルストレージ
└── Services/
    └── ConfigurationService     # 設定管理

📁 Frameworks & Drivers          # 最外層
├── MCP::Server                  # MCPフレームワーク
├── Google Calendar API          # 外部API
└── File System                  # ストレージ
```

### 3.2 依存性管理方針

#### Singletonと依存性注入の共存

```ruby
# 推奨パターン
class AnalyzeCalendarUseCase
  def initialize(
    calendar_repository: GoogleCalendarRepository.new,
    token_repository: TokenManager.instance,      # Singleton継続
    auth_service: GoogleCalendarAuthManager.instance  # Singleton継続
  )
    @calendar_repository = calendar_repository
    @token_repository = token_repository
    @auth_service = auth_service
  end
end
```

**設計原則**:
- **ドメインに適切なものはSingletonを維持**
- **テストが必要なものは注入可能にする**
- **インターフェースを明示的に定義**

### 3.3 レイヤー間通信ルール

#### 1. 依存関係ルール
```ruby
# ✅ 正しい依存方向（内向き）
UseCase → Repository Interface
Repository Implementation → UseCase Interface

# ❌ 間違った依存方向（外向き）
Entity → UseCase  # 禁止
UseCase → Controller  # 禁止
```

#### 2. データ転送オブジェクト（DTO）
```ruby
# レイヤー間でのデータ受け渡し
class AnalysisRequestDto
  attr_reader :start_date, :end_date, :color_filters
  
  def initialize(start_date:, end_date:, color_filters: nil)
    @start_date = start_date
    @end_date = end_date  
    @color_filters = color_filters
  end
end
```

---

## 4. 改善ロードマップ

### Phase 1: Domain層の確立（2-3日）

#### 1.1 エンティティ・値オブジェクト作成
```ruby
# lib/calendar_color_mcp/entities/calendar_event.rb
class CalendarEvent
  def initialize(summary:, start_time:, end_time:, color_id:, attendees:)
    # バリデーションとビジネスルール
  end
  
  def duration_hours
    # ビジネスロジック
  end
  
  def attended_by?(user_email)
    # 参加判定ロジック
  end
end
```

#### 1.2 Repository Interface定義
```ruby
# lib/calendar_color_mcp/repositories/calendar_repository_interface.rb
module CalendarRepositoryInterface
  def fetch_events(start_date, end_date)
    raise NotImplementedError
  end
end
```

### Phase 2: Use Cases層の実装（3-4日）

#### 2.1 責任の明確な分離
```ruby
# Before: 60行の巨大メソッド
def get_events(start_date, end_date)
  # 認証・取得・フィルタ・ログが混在
end

# After: 責任分離
class AnalyzeCalendarUseCase
  def execute(request_dto)
    events = @calendar_repository.fetch_events(
      request_dto.start_date, 
      request_dto.end_date
    )
    
    filtered_events = @filter_service.apply_filters(events, request_dto.filters)
    @analyzer_service.analyze(filtered_events)
  end
end
```

#### 2.2 エラーハンドリング標準化
```ruby
module CalendarColorMCP
  class UseCaseError < StandardError; end
  class AuthenticationRequiredError < UseCaseError; end
  class CalendarAccessError < UseCaseError; end
end
```

### Phase 3: Infrastructure層の再構築（2-3日）

#### 3.1 Repository実装の簡素化
```ruby  
# Before: 複数責任が混在
class GoogleCalendarClient
  def get_events(start_date, end_date)
    authenticate                              # 認証責任
    all_events = @service.list_events(...)   # API責任
    filter_attended_events(all_events)       # フィルタ責任
    # + 20行のデバッグログ                   # ログ責任
  end
end

# After: 責任の明確化
class GoogleCalendarRepository
  def fetch_events(start_date, end_date)
    @service.list_events(
      'primary',
      time_min: start_date.iso8601,
      time_max: end_date.iso8601,
      single_events: true,
      order_by: 'startTime'
    ).items
  end
end
```

#### 3.2 設定管理の一元化
```ruby
class ConfigurationService
  include Singleton
  
  def initialize
    validate_environment
  end
  
  def google_client_id
    @google_client_id ||= ENV.fetch('GOOGLE_CLIENT_ID')
  end
  
  private
  
  def validate_environment
    # 一箇所での環境変数検証
  end
end
```

### Phase 4: Interface Adapters層（1-2日）

#### 4.1 MCPツールの薄層化
```ruby
# Before: ビジネスロジックが含まれる
class AnalyzeCalendarTool < BaseTool
  def call(start_date:, end_date:, **context)
    # 50行のビジネスロジック
  end
end

# After: 薄い層（Controller的役割）
class AnalyzeCalendarTool < BaseTool  
  def call(start_date:, end_date:, include_colors: nil, exclude_colors: nil, **context)
    request = AnalysisRequestDto.new(
      start_date: Date.parse(start_date),
      end_date: Date.parse(end_date),
      color_filters: build_color_filters(include_colors, exclude_colors)
    )
    
    use_case = AnalyzeCalendarUseCase.new(
      calendar_repository: GoogleCalendarRepository.new,
      token_manager: extract_token_manager(context),
      auth_manager: extract_auth_manager(context)
    )
    
    result = use_case.execute(request)
    success_response(result.to_hash)
  rescue AuthenticationRequiredError => e
    auth_url = extract_auth_manager(context).get_auth_url
    error_response(e.message).with(auth_url: auth_url).build
  end
end
```

### Phase 5: 統合とテスト改善（2-3日）

#### 5.1 テスト戦略の改善
```ruby
# Use Caseレベルでのテスト
describe AnalyzeCalendarUseCase do
  let(:mock_calendar_repository) { instance_double(GoogleCalendarRepository) }
  let(:mock_token_manager) { TokenManager.instance }  # 実際のSingleton使用
  
  subject(:use_case) do 
    AnalyzeCalendarUseCase.new(
      calendar_repository: mock_calendar_repository,
      token_manager: mock_token_manager
    )
  end
  
  it "should analyze calendar events" do
    allow(mock_calendar_repository)
      .to receive(:fetch_events)
      .and_return([mock_event])
      
    result = use_case.execute(request_dto)
    
    expect(result).to be_success
  end
end
```

#### 5.2 既存FIXMEの解決
- ✅ Server運用時エラーハンドリング → Use Case層で統一処理
- ✅ GoogleCalendarClientビジネスロジック混在 → Repository+UseCase分離  
- ✅ BaseToolビルダーパターン → 標準エラーレスポンス採用

### 🎯 実装優先順位と期待効果

#### 高優先度（即座に効果）
1. **GoogleCalendarClientの分離**（Phase 3）
   - 60行メソッドの解決
   - テストの簡素化
   
2. **エラーハンドリング統一**（Phase 2）
   - 例外握りつぶし問題の解決
   - 統一的なエラーレスポンス

#### 中優先度（中長期的効果）  
3. **Use Cases層の確立**（Phase 2）
   - ビジネスロジックの明確化
   - 新機能追加の容易化

4. **設定管理統一**（Phase 3）
   - 重複コード削減
   - 保守性向上

#### 低優先度（将来への投資）
5. **Domain層の確立**（Phase 1）
   - 長期的な拡張性
   - ドメインロジックの保護

---

## まとめ

### ✅ Singleton継続の妥当性
- **TokenManager**: ファイル競合回避、リソース保護のため適切
- **AuthManager**: 認証状態統一、設定一元管理のため適切
- テスト上の制約は、ドメインの整合性に比べて優先度が低い

### 🎯 クリーンアーキテクチャ適用効果
1. **責任の明確化**: 各レイヤーの役割が明確になる
2. **テスタビリティ向上**: Use Case単位でのテストが容易
3. **拡張性確保**: 新機能追加時の影響範囲を局所化
4. **保守性向上**: 技術債務（FIXME）の根本的解決

### 🚀 段階的移行アプローチ  
- **Phase 3 Infrastructure層から開始**: 即座に効果が見える
- **Singleton設計は維持**: ドメインに適したパターンを尊重
- **依存性注入併用**: テスト容易性とドメイン整合性の両立

このアプローチにより、**現在のコードベースの利点を活かしつつ**、**クリーンアーキテクチャの恩恵を段階的に享受**できます。