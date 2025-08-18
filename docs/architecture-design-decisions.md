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

### 3.1 MCPサーバー向け明示的レイヤー設計

```
lib/calendar_color_mcp/
├── domain/                          # Domain層（最内層）
│   ├── entities/
│   │   ├── calendar_event.rb       # カレンダーイベントエンティティ
│   │   ├── event_filter.rb         # イベントフィルタ値オブジェクト
│   │   ├── auth_token.rb           # 認証トークンエンティティ
│   │   ├── event_filter.rb         # イベントフィルタ値オブジェクト
│   │   └── color_constants.rb      # 色IDと色名のマッピング（ビジネスドメイン知識）
│   └── services/
│       ├── event_duration_calculation_service.rb # イベント期間計算
│       └── event_filter_service.rb         # イベントフィルタリング（ビジネスルール）
├── application/                     # Application層
│   ├── use_cases/
│   │   ├── analyze_calendar_use_case.rb  # カレンダー分析UseCase
│   │   ├── authenticate_user_use_case.rb # 認証UseCase
│   │   └── filter_events_by_color_use_case.rb # 色別フィルタリングUseCase
│   └── services/
│       └── calendar_orchestration_service.rb # 複数UseCase調整（段階的実装）
├── interface_adapters/              # Interface Adapters層
│   └── tools/
│       ├── analyze_calendar_tool.rb # MCPツール（Controller的役割）
│       ├── start_auth_tool.rb       # 認証開始ツール
│       ├── check_auth_status_tool.rb # 認証状態確認ツール
│       ├── complete_auth_tool.rb    # 認証完了ツール
│       └── base_tool.rb             # ベースツール
└── infrastructure/                  # Infrastructure層（最外層）
    ├── repositories/
    │   ├── google_calendar_repository.rb   # Google Calendar API実装
    │   └── token_repository.rb             # トークンファイル管理（Phase 6でTokenManagerをここに移行）
    └── services/
        └── configuration_service.rb        # 設定管理サービス
    # デバッグログ装飾はgoogle_calendar_repository.rb内にGoogleCalendarRepositoryLogDecoratorとして統合

# モジュール名前空間設計（簡潔化）
# Domain::CalendarEvent (CalendarColorMCPプレフィックスなし)
# Domain::ColorConstants # 色IDと色名のマッピング（ビジネスドメイン知識）
# Application::AnalyzeCalendarUseCase
# Infrastructure::GoogleCalendarRepository
```

### 3.2 明示的レイヤー依存関係ルール

#### レイヤー間依存方向（内向き依存）

```ruby
# ✅ 正しい依存方向
Domain層 ← Application層 ← Interface Adapters層 ← Infrastructure層

# 具体例
class AnalyzeCalendarUseCase  # Application層
  def initialize(
    calendar_repository: nil,     # Infrastructure層への依存注入
    token_repository: TokenManager.instance,      # Singleton継続
    auth_service: GoogleCalendarAuthManager.instance  # Singleton継続
  )
    @calendar_repository = calendar_repository
    @token_repository = token_repository
    @auth_service = auth_service
  end
end

# ❌ 禁止される依存方向
# Domain層 → Application層  # 禁止
# Application層 → Interface Adapters層  # 禁止
```

**明示的レイヤー設計原則**:
- **各レイヤーの責任を明確に分離**
- **依存関係逆転原則を厳格に適用**
- **ドメインに適切なものはSingleton維持**
- **テスト容易性のための注入可能設計**

### 3.3 明示的レイヤー間通信ルール

#### 1. 厳格な依存関係制約
```ruby
# ✅ 正しい依存方向（内向き）
# Infrastructure層 → Interface Adapters層 → Application層 → Domain層

# 具体的な実装例（簡潔なモジュール名前空間）
module Infrastructure
  class GoogleCalendarRepository  # Infrastructure層
    # Application層のインターフェースを実装
    def fetch_events(start_date, end_date)
      # Google Calendar API呼び出し
    end
  end
end

module Application
  class AnalyzeCalendarUseCase  # Application層
    def initialize(calendar_repository:)  # Infrastructure層を注入
      @calendar_repository = calendar_repository
    end
    
    def execute(start_date:, end_date:, color_filters: nil, user_email:)
      # Domain層のエンティティを使用
      events = @calendar_repository.fetch_events(start_date, end_date)
      # ビジネスロジック実行
    end
  end
end

module InterfaceAdapters
  class AnalyzeCalendarTool  # Interface Adapters層
    def call(start_date:, end_date:, **context)
      # Application層のUseCaseを呼び出し
      use_case = Application::AnalyzeCalendarUseCase.new(
        calendar_repository: Infrastructure::GoogleCalendarRepository.new
      )
      use_case.execute(start_date: start_date, end_date: end_date)
    end
  end
end

# ❌ 禁止される依存方向
# Domain層 → Application層  # 絶対禁止
# Application層 → Interface Adapters層  # 絶対禁止
```

#### 2. レイヤー境界での型安全なデータ受け渡し
```ruby
# Domain層エンティティを活用したレイヤー間通信（簡潔なモジュール名前空間）
module Domain
  class CalendarEvent  # Domain層エンティティ
    def initialize(summary:, start_time:, end_time:, color_id:)
      # ドメインルールとバリデーション
    end
  end
end

module Application
  class AnalyzeCalendarUseCase
    def execute(start_date:, end_date:, color_filters: nil, user_email:)
      # Application層で直接日付バリデーション
      parsed_start_date, parsed_end_date = validate_date_range(start_date, end_date)
      
      # Infrastructure層からドメインエンティティを取得
      events = @calendar_repository.fetch_events(parsed_start_date, parsed_end_date)
      
      # Domain層サービスでビジネスロジック実行
      @analyzer_service.analyze(events)
    end
  end
end
```

---

## 4. 明示的レイヤー実装ロードマップ

### Phase 1: Domain層の確立（2-3日）

#### 1.1 ドメインエンティティ・値オブジェクト作成
```ruby
# lib/calendar_color_mcp/domain/entities/calendar_event.rb
module Domain
  class CalendarEvent
    def initialize(summary:, start_time:, end_time:, color_id:, attendees:)
      # バリデーションとビジネスルール
    end
    
    def duration_hours
      # ドメインロジック
    end
    
    def attended_by?(user_email)
      # 参加判定ドメインルール
    end
  end
end
```

#### 1.2 ドメインサービス作成

**EventFilterService（ビジネスルールフィルタリング）**
```ruby
# lib/calendar_color_mcp/domain/services/event_filter_service.rb
module Domain
  class EventFilterService
    def apply_filters(events, color_filters, user_email)
      # 参加イベントフィルタリング（ビジネスルール）
      attended_events = events.select { |event| event.attended_by?(user_email) }
      
      # 色によるフィルタリング（ビジネスルール）
      filter_by_colors(attended_events, color_filters)
    end
    
    private
    
    def filter_by_colors(events, color_filters)
      return events unless color_filters
      
      # 色による包含/除外ロジック（ドメインルール）
      if color_filters[:include_colors]
        events.select { |event| color_filters[:include_colors].include?(event.color_id) }
      elsif color_filters[:exclude_colors]
        events.reject { |event| color_filters[:exclude_colors].include?(event.color_id) }
      else
        events
      end
    end
  end
end
```

**TimeAnalysisService（既存TimeAnalyzerの移行）**
```ruby
# lib/calendar_color_mcp/domain/services/time_analysis_service.rb
module Domain
  class TimeAnalysisService
    def analyze(filtered_events)
      # filtered_eventsは Domain::EventFilterService により
      # 事前にフィルタリング済みのイベント配列
      color_breakdown = analyze_by_color(filtered_events)
      summary = generate_summary(color_breakdown, filtered_events.count)
      
      {
        color_breakdown: color_breakdown,
        summary: summary
      }
    end
    
    private
    
    def analyze_by_color(events)
      # 既存TimeAnalyzerのロジックを移行
    end
    
    def calculate_duration(event)
      # 既存TimeAnalyzerのロジックを移行
    end
    
    def generate_summary(color_breakdown, event_count)
      # 既存TimeAnalyzerのロジックを移行
    end
  end
end
```

**EventDurationCalculationService（期間計算ドメインロジック）**
```ruby
# lib/calendar_color_mcp/domain/services/event_duration_calculation_service.rb
module Domain
  class EventDurationCalculationService
    def calculate_total_duration(events)
      # 複雑なドメインロジック
    end
  end
end
```

**Domain層配置の重要性**:
- **フィルタリングはビジネスルール**: 参加判定、色選択はドメインロジック
- **Infrastructure層は技術詳細のみ**: API変換、設定管理に責任を限定
- **依存関係逆転原則**: ApplicationがDomainサービスに依存する正しい方向

### Phase 2: Application層の実装（3-4日）

#### 2.1 明示的UseCaseクラス作成
```ruby
# Before: Infrastructure層に混在
def get_events(start_date, end_date)
  # 認証・取得・フィルタ・ログが混在
end

# After: Application層での責任分離
# lib/calendar_color_mcp/application/use_cases/analyze_calendar_use_case.rb
module Application
  class AnalyzeCalendarUseCase
    def initialize(
      calendar_repository:,  # Infrastructure層への依存注入
      event_filter_service:, # Domain層サービス
      token_manager: TokenManager.instance,
      auth_manager: GoogleCalendarAuthManager.instance
    )
      @calendar_repository = calendar_repository
      @event_filter_service = event_filter_service
      @token_manager = token_manager
      @auth_manager = auth_manager
    end
    
    def execute(start_date:, end_date:, color_filters: nil, user_email:)
      # 1. Application層での直接日付バリデーション
      parsed_start_date, parsed_end_date = validate_date_range(start_date, end_date)
      
      # 2. Infrastructure層を通じてデータ取得
      events = @calendar_repository.fetch_events(parsed_start_date, parsed_end_date)
      
      # 3. Domain層サービスでフィルタリング
      filtered_events = @event_filter_service.apply_filters(events, color_filters, user_email)
      
      # 4. Domain層サービスで分析
      Domain::EventDurationCalculationService.new.calculate_total_duration(filtered_events)
    end
    
    private
    
    def validate_date_range(start_date, end_date)
      parsed_start = Date.parse(start_date.to_s)
      parsed_end = Date.parse(end_date.to_s)
      
      if parsed_end < parsed_start
        raise Application::ValidationError, "End date must be after start date"
      end
      
      [parsed_start, parsed_end]
    end
  end
end
```

#### 2.2 エラーハンドリング標準化と層別責任分離

**現在の問題**: 全エラーが単一ファイルに集約され、依存関係逆転原則に違反

**解決策**: 各層での適切なエラー定義と層間変換

```ruby
# lib/calendar_color_mcp/application/errors.rb (Application層)
module Application
  # 基底エラー
  class ApplicationError < StandardError; end
  
  # ビジネスロジック実行エラー（Use Case、ワークフロー関連）
  class BusinessLogicError < ApplicationError; end
  
  # 認証・認可エラー（ユーザー認証、権限関連）
  class AuthenticationError < ApplicationError; end
  
  # データ検証エラー（入力データ、ビジネスルール検証関連）
  class ValidationError < ApplicationError; end
end

# lib/calendar_color_mcp/infrastructure/errors.rb (Infrastructure層)
module Infrastructure
  # 基底エラー
  class InfrastructureError < StandardError; end
  
  # 外部サービス連携エラー（Google Calendar API等）
  class ExternalServiceError < InfrastructureError; end
  
  # 設定・構成エラー（環境変数、設定ファイル等）  
  class ConfigurationError < InfrastructureError; end
  
  # データ処理エラー（ファイルI/O、フィルタリング等）
  class DataProcessingError < InfrastructureError; end
end

# lib/calendar_color_mcp/domain/errors.rb (Domain層)
module Domain
  # 基底エラー
  class DomainError < StandardError; end
  
  # ビジネスルール違反エラー（ドメインルール、制約違反関連）
  class BusinessRuleViolationError < DomainError; end
  
  # データ整合性エラー（エンティティ、値オブジェクトの整合性関連）
  class DataIntegrityError < DomainError; end
end

# lib/calendar_color_mcp/interface_adapters/errors.rb (Interface Adapters層)
module InterfaceAdapters
  # 基底エラー
  class InterfaceAdapterError < StandardError; end
  
  # プロトコル変換エラー（MCP変換、パラメータ変換関連）
  class ProtocolError < InterfaceAdapterError; end
  
  # レスポンス生成エラー（JSON生成、フォーマット関連）
  class ResponseError < InterfaceAdapterError; end
end
```

**エラー変換の原則**:
- Infrastructure層エラー → Application層エラーに変換
- Application層エラー → Interface Adapters層でMCPレスポンスに変換
- 各層は自分より内側の層のエラーのみを知る（依存関係逆転原則）

### Phase 3: Infrastructure層の再構築（2-3日）

#### 3.1 明示的Repository実装
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

# After: Infrastructure層での責任明確化
# lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository.rb
module Infrastructure
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
end

# lib/calendar_color_mcp/domain/services/event_filter_service.rb
module Domain
  class EventFilterService
    def apply_filters(events, color_filters, user_email)
      # 参加イベントフィルタリング（ビジネスルール）
      attended_events = events.select { |event| event.attended_by?(user_email) }
      
      # 色によるフィルタリング（ビジネスルール）
      filter_by_colors(attended_events, color_filters)
    end
    
    private
    
    def filter_by_colors(events, color_filters)
      return events unless color_filters
      
      # 色による包含/除外ロジック（ドメインルール）
      if color_filters[:include_colors]
        events.select { |event| color_filters[:include_colors].include?(event.color_id) }
      elsif color_filters[:exclude_colors]
        events.reject { |event| color_filters[:exclude_colors].include?(event.color_id) }
      else
        events
      end
    end
  end
end

# lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository.rb (同ファイル内)
module Infrastructure
  class GoogleCalendarRepositoryLogDecorator
    def initialize(repository)
      @repository = repository
    end
    
    def fetch_events(start_date, end_date)
      events = @repository.fetch_events(start_date, end_date)
      log_debug_info(events)
      events
    end
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

#### 4.1 明示的Controller層としてのMCPツール
```ruby
# Before: ビジネスロジックが含まれる
class AnalyzeCalendarTool < BaseTool
  def call(start_date:, end_date:, **context)
    # 50行のビジネスロジック
  end
end

# After: Interface Adapters層でのController的役割（簡潔なモジュール名前空間）
# lib/calendar_color_mcp/interface_adapters/tools/analyze_calendar_tool.rb
module InterfaceAdapters
  class AnalyzeCalendarTool < BaseTool  
    def call(start_date:, end_date:, include_colors: nil, exclude_colors: nil, **context)
      # 1. リクエストパラメータの変換（Interface Adapters層の責任）
      parsed_start_date = Date.parse(start_date)
      parsed_end_date = Date.parse(end_date)
      color_filters = build_color_filters(include_colors, exclude_colors)
      user_email = extract_user_email(context)
      
      # 2. Application層UseCaseの組み立て
      use_case = Application::AnalyzeCalendarUseCase.new(
        calendar_repository: Infrastructure::GoogleCalendarRepository.new,
        event_filter_service: Domain::EventFilterService.new,
        token_manager: extract_token_manager(context),
        auth_manager: extract_auth_manager(context)
      )
      
      # 3. UseCaseの実行
      result = use_case.execute(
        start_date: parsed_start_date,
        end_date: parsed_end_date,
        color_filters: color_filters,
        user_email: user_email
      )
      
      # 4. レスポンスの変換（Interface Adapters層の責任）
      success_response(format_response(result))
    rescue Application::AuthenticationError => e
      handle_authentication_error(e)
    rescue Application::ValidationError => e
      handle_parameter_error(e)
    rescue Application::BusinessLogicError => e
      handle_business_logic_error(e)
    end
    
    private
    
    def format_response(result)
      # Interface Adapters層でのレスポンス変換
    end
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
      
    result = use_case.execute(
      start_date: Date.parse('2024-01-01'),
      end_date: Date.parse('2024-01-31'),
      user_email: 'test@example.com'
    )
    
    expect(result).to be_success
  end
end
```

#### 5.2 明示的レイヤー構造での技術債務解決
- ✅ Server運用時エラーハンドリング → Application層でのエラーハンドリング統一
- ✅ GoogleCalendarClientビジネスロジック混在 → Infrastructure層Repository + Application層UseCase完全分離  
- ✅ BaseToolビルダーパターン → Interface Adapters層での標準レスポンス変換パターン採用
- ✅ レイヤー間依存関係 → 依存関係逆転原則の厳格適用

### 🎯 明示的レイヤー実装の優先順位と期待効果

#### 高優先度（即座に効果）
1. **Infrastructure層の完全分離**（Phase 3）
   - 60行メソッドの責任分離
   - Repository・Service・Decoratorの明確化
   - テストの簡素化
   
2. **Application層エラーハンドリング統一**（Phase 2）
   - UseCase単位での統一例外処理
   - レイヤー境界での適切なエラー変換

#### 中優先度（中長期的効果）  
3. **Application層UseCase確立**（Phase 2）
   - ビジネスロジックのApplication層集約
   - 個別Use Caseの確立を最優先
   - **CalendarOrchestrationService**: 複数Use Case間の調整が必要になった段階で導入する段階的アプローチ
   - 新機能追加時の影響局所化

4. **Interface Adapters層Controller化**（Phase 4）
   - MCPツールの薄層化
   - リクエスト/レスポンス変換の統一
   - プロトコル変更への対応力向上

#### 低優先度（将来への投資）
5. **Domain層の確立**（Phase 1）
   - ドメインエンティティでのビジネスルール保護
   - 値オブジェクトによる型安全性
   - 長期的なドメインモデル進化基盤

### OrchestrationServiceの段階的実装方針

**段階1: 個別Use Caseの確立**
- まず各Use Case（analyze_calendar_use_case.rb、authenticate_user_use_case.rb等）を独立して実装
- 各Use Caseが単独で動作することを確認

**段階2: 必要に応じたOrchestration追加**
- 複数Use Case間で複雑な調整が必要になった場合のみCalendarOrchestrationServiceを導入
- YAGNI原則（You Aren't Gonna Need It）に従い、実際の必要性が明確になってから実装

---

## まとめ

### ✅ 明示的レイヤー構造でのSingleton妥当性
- **TokenManager**: Infrastructure層での適切なSingleton（ファイル競合回避、リソース保護）
- **AuthManager**: Infrastructure層での適切なSingleton（認証状態統一、設定一元管理）
- **ConfigurationService**: Infrastructure層での新規Singleton（環境変数管理一元化）
- テスト上の制約よりもドメインの整合性とレイヤー責任を優先

### 🎯 明示的レイヤー構造の適用効果
1. **責任の明確化**: 各レイヤーディレクトリで物理的に責任分離
2. **依存関係の可視化**: レイヤー間の依存方向が明確
3. **テスタビリティ向上**: レイヤー単位での独立テストが容易
4. **拡張性確保**: 新機能追加時の配置先とレイヤー間インターフェースが明確
5. **保守性向上**: 技術債務（FIXME）の根本的解決とレイヤー責任の明確化
6. **新規開発者の理解促進**: ディレクトリ構造でアーキテクチャが自明

### 🚀 明示的レイヤー移行アプローチ  
- **Phase 3 Infrastructure層から開始**: 物理的なディレクトリ分離で即座に効果
- **Singleton設計は適切なレイヤーで維持**: Infrastructure層での適切なパターン継続
- **レイヤー間依存性注入**: 依存関係逆転原則の厳格適用
- **段階的モジュール名前空間**: 各Phaseでレイヤー名前空間を段階的に導入

この明示的レイヤー構造アプローチにより、**現在のコードベースの利点を活かしつつ**、**クリーンアーキテクチャの恩恵を物理的なディレクトリ構造で明確化し、段階的に享受**できます。各レイヤーの責任が明確になり、新規開発者でもアーキテクチャを直感的に理解できる構造を実現します。

---

## Phase 6: 認証アーキテクチャの改善

### 🎯 目的
- **GoogleCalendarAuthManagerの責務分離**: OAuth通信とビジネスロジックの明確な分離
- **Singletonパターンの段階的除去**: テスト容易性と依存性注入の改善
- **Infrastructure層への適切な配置**: OAuth API通信の責任明確化

### 6.1 現在の認証アーキテクチャの問題分析

#### 📋 GoogleCalendarAuthManagerの責務混在
```ruby
# lib/calendar_color_mcp/google_calendar_auth_manager.rb (現状)
class GoogleCalendarAuthManager
  include Singleton
  
  def get_auth_url
    # 1. 設定値検証責任
    # 2. OAuth URL生成責任  
    # 3. 認証フロー管理責任
  end
  
  def complete_auth_from_code(code)
    # 1. トークン交換API呼び出し責任
    # 2. トークン保存責任
    # 3. エラーハンドリング責任
  end
  
  def token_exist?
    # TokenManagerへの委譲（責務不明確）
  end
end
```

**明確化された問題点**:
- **責務混在**: OAuth API通信（Infrastructure）とビジネスロジック（Application）が混在
- **Singleton制約**: テスト時の依存性注入が困難
- **レイヤー責任不明確**: Infrastructure層の概念がない状態でのGoogle OAuth API通信
- **認証Use Caseの未活用**: 既存のAuthentication Use Caseが実質的に未使用

### 6.2 クリーンアーキテクチャ原則に基づく解決策

#### Infrastructure::GoogleOAuthService（新規作成）
```ruby
# lib/calendar_color_mcp/infrastructure/services/google_oauth_service.rb
module Infrastructure
  class GoogleOAuthService
    def initialize(config_service: ConfigurationService.instance)
      @config_service = config_service
      @oauth_client = build_oauth_client
    end
    
    def generate_auth_url
      @oauth_client.authorization_uri(
        scope: ['https://www.googleapis.com/auth/calendar.readonly'],
        access_type: 'offline',
        approval_prompt: 'force'
      ).to_s
    rescue => e
      raise Infrastructure::ExternalServiceError, "OAuth URL生成に失敗しました: #{e.message}"
    end
    
    def exchange_code_for_token(auth_code)
      @oauth_client.code = auth_code
      @oauth_client.fetch_access_token!
      @oauth_client
    rescue => e
      raise Infrastructure::ExternalServiceError, "トークン交換に失敗しました: #{e.message}"
    end
    
    private
    
    def build_oauth_client
      Signet::OAuth2::Client.new(
        client_id: @config_service.google_client_id,
        client_secret: @config_service.google_client_secret,
        authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        redirect_uri: 'urn:ietf:wg:oauth:2.0:oob'
      )
    end
  end
end
```

**Infrastructure層配置の根拠**:
- **外部サービス通信**: Google OAuth APIとの通信は技術的詳細
- **設定依存**: ConfigurationServiceを活用した統一的な設定管理
- **プロトコル固有**: OAuth 2.0プロトコルの実装詳細

#### Application::AuthenticationUseCase（既存の強化）
```ruby
# lib/calendar_color_mcp/application/use_cases/authentication_use_case.rb
module Application
  class AuthenticationUseCase
    def initialize(
      oauth_service: Infrastructure::GoogleOAuthService.new,
      token_repository: Infrastructure::TokenRepository.instance  # Singleton使用
    )
      @oauth_service = oauth_service
      @token_repository = token_repository
    end
    
    def start_authentication
      auth_url = @oauth_service.generate_auth_url
      
      {
        auth_url: auth_url,
        instructions: "ブラウザでURLを開き、認証コードを取得してください"
      }
    rescue Infrastructure::ExternalServiceError => e
      raise Application::AuthenticationError, "認証開始に失敗しました: #{e.message}"
    end
    
    def complete_authentication(auth_code)
      validate_auth_code(auth_code)
      
      credentials = @oauth_service.exchange_code_for_token(auth_code)
      @token_repository.save_credentials(credentials)
      
      {
        success: true,
        message: "認証が完了しました"
      }
    rescue Infrastructure::ExternalServiceError => e
      raise Application::AuthenticationError, "認証完了に失敗しました: #{e.message}"
    rescue => e
      raise Application::AuthenticationError, "予期しないエラーが発生しました: #{e.message}"
    end
    
    def check_authentication_status
      {
        authenticated: @token_repository.token_exist?,
        token_file_exists: File.exist?(@token_repository.instance_variable_get(:@token_file_path))
      }
    end
    
    private
    
    def validate_auth_code(auth_code)
      if auth_code.nil? || auth_code.strip.empty?
        raise Application::ValidationError, "認証コードが入力されていません"
      end
    end
  end
end
```

**Application層強化の根拠**:
- **ビジネスフロー管理**: 認証開始→完了→状態確認の一連のワークフロー
- **エラー変換**: Infrastructure層エラーをApplication層エラーに適切に変換
- **TokenManager統合**: 既存のSingleton（適切な設計）との連携

### 6.3 Interface Adapters層の改善

#### Interface Adaptersツールの Use Case 使用への変更
```ruby
# lib/calendar_color_mcp/interface_adapters/tools/start_auth_tool.rb
module InterfaceAdapters
  class StartAuthTool < BaseTool
    def call(**context)
      use_case = Application::AuthenticationUseCase.new
      result = use_case.start_authentication
      
      success_response({
        message: "認証プロセスを開始しました",
        auth_url: result[:auth_url],
        instructions: result[:instructions]
      })
    rescue Application::AuthenticationError => e
      error_response("認証開始エラー: #{e.message}")
    rescue => e
      logger.error "Unexpected error in start_auth: #{e.message}"
      error_response("認証開始時に予期しないエラーが発生しました")
    end
  end
end

# lib/calendar_color_mcp/interface_adapters/tools/check_auth_status_tool.rb
module InterfaceAdapters
  class CheckAuthStatusTool < BaseTool
    def call(**context)
      use_case = Application::AuthenticationUseCase.new
      result = use_case.check_authentication_status
      
      success_response({
        authenticated: result[:authenticated],
        token_file_exists: result[:token_file_exists],
        status_message: build_status_message(result)
      })
    rescue Application::AuthenticationError => e
      error_response("認証状態確認エラー: #{e.message}")
    rescue => e
      logger.error "Unexpected error in check_auth_status: #{e.message}"
      error_response("認証状態確認時に予期しないエラーが発生しました")
    end
    
    private
    
    def build_status_message(result)
      if result[:authenticated]
        "認証済みです"
      else
        "認証が必要です。start_authを実行してください"
      end
    end
  end
end
```

**Interface Adapters改善の根拠**:
- **Controller的役割**: MCPプロトコルからUse Caseへの変換のみ
- **統一的エラーハンドリング**: Application層エラーのMCPレスポンス変換
- **依存性の明確化**: Use Caseへの依存をコンストラクタで明示

### 6.4 server.rbでの依存性注入の改善

#### server_contextの更新（TokenRepositoryへの移行）
```ruby
# lib/calendar_color_mcp/server.rb (該当部分の更新)
def setup_server_context
  oauth_service = Infrastructure::GoogleOAuthService.new
  calendar_repository = Infrastructure::GoogleCalendarRepositoryLogDecorator.new(
    Infrastructure::GoogleCalendarRepository.new
  )
  
  {
    oauth_service: oauth_service,                                    # 新規追加
    calendar_repository: calendar_repository,
    token_repository: Infrastructure::TokenRepository.instance      # TokenManagerから移行（適切なSingleton）
    # auth_manager: GoogleCalendarAuthManagerは段階的に削除
  }
end
```

**server.rb改善の根拠**:
- **Infrastructure層統一**: OAuth通信もRepository層と同様の注入方式
- **TokenManager維持**: 適切なSingletonとして継続（ファイル管理の一意性）
- **段階的移行**: 既存機能を維持しながらの安全な移行

### 6.5 段階的移行戦略

#### 移行フェーズ
1. **Infrastructure::GoogleOAuthService作成**: OAuth API通信の分離
2. **Application::AuthenticationUseCase強化**: ビジネスロジックの統合
3. **Interface Adaptersの段階的更新**: ツール単位での移行
4. **server.rbからの段階的除去**: 依存関係の段階的切り替え
5. **テスト更新**: 新アーキテクチャでのテスト実装
6. **GoogleCalendarAuthManager完全削除**: 最終的な旧コード除去

#### 影響範囲の明確化
```ruby
# 現在GoogleCalendarAuthManagerを使用している箇所（移行対象）
# - StartAuthTool: Use Case使用に変更
# - CheckAuthStatusTool: Use Case使用に変更
# - AnalyzeCalendarTool: 認証エラー時のauth_url取得方法変更
# - server.rb: server_context設定から除去
```

**移行戦略の利点**:
- **漸進的変更**: 一度に全体を変更せず、段階的な安全な移行
- **機能保持**: 既存機能を維持しながらのアーキテクチャ改善
- **テスト継続**: 各段階でテスト成功を維持

### 6.6 認証フローでのエラー変換パターン

#### レイヤー間エラー変換の明確化
```ruby
# Infrastructure → Application
rescue Infrastructure::ExternalServiceError => e
  raise Application::AuthenticationError, "認証プロセスで外部サービスエラー: #{e.message}"

# Application → Interface Adapters  
rescue Application::AuthenticationError => e
  error_response("認証エラー: #{e.message}")
rescue Application::ValidationError => e
  error_response("入力エラー: #{e.message}")

# Interface Adapters → MCP Response
def error_response(message, **additional_data)
  response_data = {
    success: false,
    error: message
  }.merge(additional_data)

  MCP::Tool::Response.new([{
    type: "text", 
    text: response_data.to_json
  }])
end
```

**エラー変換パターンの根拠**:
- **責任分離**: 各層は自分の責任範囲のエラーのみ生成
- **依存関係逆転**: 外層が内層のエラーを知り、適切に変換
- **一貫性**: 全認証ツールで統一的なエラーハンドリング

### 6.7 期待効果とアーキテクチャ整合性

#### 責任分離の明確化
- ✅ **OAuth API通信**: Infrastructure::GoogleOAuthService（技術的詳細）
- ✅ **認証ビジネスロジック**: Application::AuthenticationUseCase（ワークフロー管理）
- ✅ **トークン管理**: CalendarColorMCP::TokenManager（適切なSingleton維持）
- ✅ **プロトコル変換**: InterfaceAdapters::*Tool（MCP変換のみ）

#### クリーンアーキテクチャ整合性
- ✅ **層間依存関係**: Application → Infrastructure（正しい方向）
- ✅ **エラー変換**: Infrastructure → Application → Interface Adapters
- ✅ **単一責任原則**: 各クラスが明確で独立した責任を持つ
- ✅ **依存性注入**: Singletonからの脱却とテスト容易性向上

#### 既存Use Caseの活用
- ✅ **AuthenticationUseCase**: 実際のツールから使用される実用的な実装
- ✅ **CheckAuthStatusUseCase**: CheckAuthStatusToolで活用
- ✅ **統一的認証フロー**: 全認証関連ツールでの一貫したUse Case使用

### 6.9 TokenManagerのInfrastructure層移行

#### 📋 TokenManagerの現在の問題
```ruby
# lib/calendar_color_mcp/token_manager.rb (現状)
class TokenManager
  include Singleton
  
  def save_credentials(credentials)
    # ファイルI/O操作（Infrastructure層の責任）
  end
  
  def load_credentials
    # 外部ライブラリ依存（Infrastructure層の責任）
    config = Infrastructure::ConfigurationService.instance
    credentials = Google::Auth::UserRefreshCredentials.new(...)
  end
end
```

**問題点**:
- **技術的責任**: ファイルI/O、外部ライブラリ操作はInfrastructure層の責任
- **設定サービス依存**: 既にInfrastructure::ConfigurationServiceを使用
- **レイヤー責任不明確**: ルートレベル配置により層の責任が曖昧

**Infrastructure層移行の根拠**:
現在のTokenManagerは以下の理由でInfrastructure層に配置すべきです：

1. **ファイルI/O操作**: `token.json`への読み書きは技術的詳細
2. **外部ライブラリ依存**: `Google::Auth::UserRefreshCredentials`の操作
3. **設定サービス統合**: `Infrastructure::ConfigurationService`との自然な連携
4. **責任の明確化**: 認証トークンの永続化という技術的責任

#### ✅ 解決策: Infrastructure::TokenRepositoryへの移行（Singletonパターン採用）

```ruby
# lib/calendar_color_mcp/infrastructure/repositories/token_repository.rb
module Infrastructure
  class TokenRepository
    include Singleton  # ファイル安全性とトークン一意性のためSingleton採用
    
    def initialize
      @config_service = ConfigurationService.instance
      @token_file_path = build_token_file_path
      @mutex = Mutex.new  # スレッドセーフティ確保
    end
    
    def save_credentials(credentials)
      @mutex.synchronize do
        # 単一インスタンスによる安全なファイルI/O操作
        token_data = {
          access_token: credentials.access_token,
          refresh_token: credentials.refresh_token,
          expires_at: credentials.expires_at&.to_i,
          saved_at: Time.now.to_i
        }
        File.write(@token_file_path, token_data.to_json)
      end
    end
    
    def load_credentials
      return nil unless File.exist?(@token_file_path)
      
      token_data = JSON.parse(File.read(@token_file_path))
      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: @config_service.google_client_id,
        client_secret: @config_service.google_client_secret,
        refresh_token: token_data['refresh_token'],
        access_token: token_data['access_token']
      )
      
      if token_data['expires_at']
        credentials.expires_at = Time.at(token_data['expires_at'])
      end
      
      credentials
    rescue JSON::ParserError, KeyError => e
      logger.debug "Token file error: #{e.message}"
      nil
    end
    
    def token_exist?
      !load_credentials.nil?
    rescue
      false
    end
    
    def clear_credentials
      @mutex.synchronize do
        File.delete(@token_file_path) if File.exist?(@token_file_path)
      end
    end
    
    private
    
    def build_token_file_path
      project_root = File.expand_path('../../../..', __FILE__)
      File.join(project_root, 'token.json')
    end
  end
end
```

#### 🎯 TokenRepositoryでのSingleton採用理由

**1. ファイル競合の回避**
```ruby
# 複数インスタンスの場合の問題
instance1 = Infrastructure::TokenRepository.new
instance2 = Infrastructure::TokenRepository.new

# 同時アクセスでファイル競合のリスク
instance1.save_credentials(credentials_a)  # token.json書き込み
instance2.save_credentials(credentials_b)  # 同時に書き込み → 競合！
```

**2. トークンの一意性保証**
- OAuth2トークンは本質的にアプリケーション全体で**一意の状態**
- 複数のTokenRepositoryインスタンスは論理的に矛盾
- ファイルロック機構の複雑化を回避

**3. MCPツール間での状態共有**
```ruby
# 全MCPツールで同じ認証状態を参照
StartAuthTool    → token_repository.clear_credentials
CompleteAuthTool → token_repository.save_credentials  
AnalyzeCalendarTool → token_repository.load_credentials
```

**Infrastructure層配置の根拠**:
- **ファイルI/O操作**: `token.json`への読み書きは技術的詳細
- **外部ライブラリ依存**: `Google::Auth::UserRefreshCredentials`の操作
- **設定サービス統合**: `Infrastructure::ConfigurationService`との自然な連携
- **責任の明確化**: 認証トークンの永続化という技術的責任

#### Phase 6でのTokenManager移行ステップ

1. **Infrastructure::TokenRepository作成**（Singletonパターン）
2. **Application::AuthenticationUseCase更新**: TokenRepositoryを注入
3. **server.rbの依存性注入更新**: TokenRepositoryに変更
4. **テスト更新**: 新アーキテクチャでのテスト実装（Singleton考慮）
5. **TokenManager段階的廃止**: 旧コード除去

#### 期待効果
- ✅ **層の責任明確化**: Infrastructure層での適切な技術的責任
- ✅ **依存性注入改善**: Singletonからの脱却とテスト容易性向上
- ✅ **アーキテクチャ整合性**: クリーンアーキテクチャの原則遵守
- ✅ **設定管理統一**: ConfigurationServiceとの一元的な連携

### 6.10 GoogleCalendarRepositoryのDomainオブジェクト変換

#### 📋 現在のClean Architecture違反問題

```ruby
# lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository.rb:28 (現状)
def fetch_events(start_date, end_date)
  # Google Calendar API呼び出し
  response = @service.list_events(...)
  
  # TODO:ここでdomainのオブジェクトに変換しなくていいのか？
  response.items  # Google APIオブジェクトを直接返している
end
```

**問題点**:
- **Clean Architecture違反**: Infrastructure層がGoogle APIオブジェクトを直接返している
- **Domain層のInfrastructure依存**: EventFilterServiceとTimeAnalysisServiceがGoogle API構造に依存
- **レイヤー境界の不明確**: 外部APIの詳細がDomain層まで漏出

#### ✅ 解決策: Infrastructure層でのDomain変換実装

**1. Domain ValueObject作成**
```ruby
# lib/calendar_color_mcp/domain/entities/attendee.rb
module Domain
  class Attendee
    attr_reader :email, :response_status, :self

    def initialize(email:, response_status:, self: false)
      @email = email
      @response_status = response_status
      @self = self
    end

    def accepted?
      @response_status == 'accepted'
    end
  end
end

# lib/calendar_color_mcp/domain/entities/organizer.rb
module Domain
  class Organizer
    attr_reader :email, :display_name, :self

    def initialize(email:, display_name: nil, self: false)
      @email = email
      @display_name = display_name
      @self = self
    end
  end
end
```

**2. GoogleCalendarRepository変換メソッド追加**
```ruby
# lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository.rb
module Infrastructure
  class GoogleCalendarRepository
    def fetch_events(start_date, end_date)
      # Google Calendar API呼び出し
      response = @service.list_events(...)

      # Google API Event → Domain::CalendarEvent変換
      response.items.map { |api_event| convert_to_domain_event(api_event) }
    end

    private

    def convert_to_domain_event(api_event)
      Domain::CalendarEvent.new(
        summary: api_event.summary,
        start_time: extract_start_time(api_event),
        end_time: extract_end_time(api_event),
        color_id: api_event.color_id&.to_i || Domain::ColorConstants::DEFAULT_COLOR_ID,
        attendees: convert_attendees(api_event.attendees),
        organizer: convert_organizer(api_event.organizer)
      )
    end

    def extract_start_time(api_event)
      if api_event.start.date_time
        api_event.start.date_time
      elsif api_event.start.date
        Date.parse(api_event.start.date).to_time
      end
    end

    def convert_attendees(api_attendees)
      return [] unless api_attendees
      
      api_attendees.map do |api_attendee|
        Domain::Attendee.new(
          email: api_attendee.email,
          response_status: api_attendee.response_status,
          self: api_attendee.self || false
        )
      end
    end
  end
end
```

**3. Domain層のGoogle API依存除去**
```ruby
# lib/calendar_color_mcp/domain/services/event_filter_service.rb
module Domain
  class EventFilterService
    def apply_filters(events, color_filters, user_email)
      # Domain::CalendarEventのメソッドを使用
      attended_events = events.select { |event| event.attended_by?(user_email) }
      filter_by_colors(attended_events, color_filters)
    end
  end
end

# lib/calendar_color_mcp/domain/services/time_analysis_service.rb  
module Domain
  class TimeAnalysisService
    def calculate_duration(event)
      # CalendarEventのduration_hoursメソッドを使用
      event.duration_hours
    end

    def format_event_time(event)
      # 統一化された時間フォーマット
      if event.start_time
        event.start_time.strftime('%Y-%m-%d %H:%M')
      else
        'Unknown time'
      end
    end
  end
end
```

#### Infrastructure層変換の根拠

- **責任の明確化**: Infrastructure層は外部APIからDomainオブジェクトへの変換を担当
- **依存関係逆転**: Domain層がInfrastructureの詳細から独立
- **変更影響の局所化**: Google API変更時の影響をInfrastructure層に限定
- **テスト容易性**: Domain層のテストでGoogle API依存が不要

#### Application層への影響なし

```ruby
# lib/calendar_color_mcp/application/use_cases/analyze_calendar_use_case.rb
def execute(start_date:, end_date:, color_filters: nil, user_email:)
  # インターフェースは変わらず、内部でDomain::CalendarEvent配列を受け取る
  events = @calendar_repository.fetch_events(parsed_start_date, parsed_end_date)
  filtered_events = @filter_service.apply_filters(events, color_filters, user_email)
  @analyzer_service.analyze(filtered_events)
end
```

**Phase 6実装により**、GoogleCalendarAuthManagerとTokenManagerの責務分離に加えて、GoogleCalendarRepositoryのDomain変換実装により、クリーンアーキテクチャの原則に完全準拠した統合的なシステムが実現されます。これにより、Infrastructure層の技術的詳細がDomain層から完全に隠蔽され、長期的な保守性と拡張性が大幅に向上します。
