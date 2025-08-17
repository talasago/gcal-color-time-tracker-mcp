# Calendar Color MCP リアーキテクチャ実装計画書

## 概要

アーキテクチャ設計決定書に基づき、現在のコードベースをクリーンアーキテクチャに段階的に移行する具体的な実装計画です。即座に効果が得られるPhase 3（Infrastructure層）から開始し、設計決定書で推奨されているSingletonパターンを維持しながら責任分離を実現します。

## 📋 目次

1. [実行順序と優先度](#実行順序と優先度)
2. [Phase 3: Infrastructure層の再構築](#phase-3-infrastructure層の再構築)
3. [Phase 2: Use Cases層の実装](#phase-2-use-cases層の実装)
4. [Phase 4: Interface Adapters層](#phase-4-interface-adapters層)
5. [Phase 1: Domain層の確立](#phase-1-domain層の確立)
6. [Phase 5: 統合とテスト改善](#phase-5-統合とテスト改善)
7. [重要な設計決定](#重要な設計決定)
8. [ディレクトリ構造設計](#ディレクトリ構造設計)
9. [FIXME解決リスト](#fixme解決リスト)
10. [期待効果](#期待効果)

---

## 実行順序と優先度

### 🎯 実装優先順位（設計決定書推奨）

```
Phase 3 (高優先度) → Phase 2 (中優先度) → Phase 4 (中優先度) → Phase 1 (低優先度) → Phase 5 (統合)
```

| Phase | 内容 | 期間 | 優先度 | 期待効果 |
|-------|-----|------|--------|----------|
| **Phase 3** | Infrastructure層ディレクトリ分離 | 1-2日 | 🔴 高 | 即座に効果（60行メソッド解決、物理的責任分離） |
| **Phase 2** | Application層ディレクトリ作成 | 2-3日 | 🟡 中 | 中長期効果（UseCase集約、ビジネスロジック明確化） |
| **Phase 4** | Interface Adapters層ディレクトリ作成 | 1日 | 🟡 中 | Controller層明確化、MCPツール薄層化 |
| **Phase 1** | Domain層ディレクトリ作成 | 1-2日 | 🟢 低 | 将来への投資（ドメインモデル拡張性確保） |
| **Phase 5** | レイヤー間統合とテスト改善 | 1-2日 | ⚪ 統合 | 全レイヤー統合と品質保証 |

---

## Phase 3: Infrastructure層の再構築

### 🎯 目的
- **即座の効果**: 60行の巨大メソッド解決
- **重複コード削減**: 環境変数検証の一元化
- **責任分離**: API・フィルタ・ログの責任明確化

### 3.1 GoogleCalendarRepositoryの作成

#### 📋 現在の問題
```ruby
# lib/calendar_color_mcp/google_calendar_client.rb:22-65 (60行の巨大メソッド)
def get_events(start_date, end_date)
  authenticate                              # 認証責任
  all_events = @service.list_events(...)    # API呼び出し責任
  attended_events = filter_attended_events(all_events)  # ビジネスロジック責任
  
  # + 20行のデバッグログ出力責任
  logger.debug "=== Google Calendar API Response Debug ==="
  # ...20行のログ出力
  
  attended_events
end
```

#### ✅ 解決策: 責任分離

**1. GoogleCalendarRepository（純粋なAPI層）**
```ruby
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
```

**2. EventFilterService（フィルタリング責任）**
```ruby
# lib/calendar_color_mcp/domain/services/event_filter_service.rb  
module Domain
  class EventFilterService
    def filter_attended_events(events, user_email)
      events.select { |event| event.attended_by?(user_email) }
    end
    
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

**3. GoogleCalendarRepositoryLogDecorator（ログ責任分離）**
```ruby
# lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository.rb (同ファイル内)
module Infrastructure
  class GoogleCalendarRepositoryLogDecorator
    def initialize(repository)
      @repository = repository
    end
    
    def fetch_events(start_date, end_date)
      events = @repository.fetch_events(start_date, end_date)
      log_debug_info(events, start_date, end_date)
      events
    end
  end
end
```

### 3.2 ConfigurationServiceの作成

#### 📋 現在の問題
**重複する環境変数検証**:
- `server.rb:55-78`: サーバー起動時の検証
- `google_calendar_auth_manager.rb:32-41`: 認証URL生成時の検証

```ruby
# server.rb内の重複コード
if ENV['GOOGLE_CLIENT_ID'].nil? || ENV['GOOGLE_CLIENT_ID'].empty?
  missing_vars << 'GOOGLE_CLIENT_ID'
end

# google_calendar_auth_manager.rb内の重複コード  
if ENV['GOOGLE_CLIENT_ID'].nil? || ENV['GOOGLE_CLIENT_ID'].empty?
  raise "GOOGLE_CLIENT_ID not set. Check .env file."
end
```

#### ✅ 解決策: 設定管理一元化

```ruby
# lib/calendar_color_mcp/infrastructure/services/configuration_service.rb
module Infrastructure
  class ConfigurationService
    include Singleton
    
    def initialize
      validate_environment
    end
    
    def google_client_id
      @google_client_id ||= ENV.fetch('GOOGLE_CLIENT_ID')
    end
    
    def google_client_secret
      @google_client_secret ||= ENV.fetch('GOOGLE_CLIENT_SECRET')
    end
    
    private
    
    def validate_environment
      missing_vars = []
      
      missing_vars << 'GOOGLE_CLIENT_ID' if env_missing?('GOOGLE_CLIENT_ID')
      missing_vars << 'GOOGLE_CLIENT_SECRET' if env_missing?('GOOGLE_CLIENT_SECRET')
      
      raise_missing_env_error(missing_vars) unless missing_vars.empty?
    end
    
    def env_missing?(var_name)
      ENV[var_name].nil? || ENV[var_name].empty?
    end
    
    def raise_missing_env_error(missing_vars)
      error_msg = build_error_message(missing_vars)
      logger.error error_msg
      raise error_msg
    end
  end
end
```

### 3.3 TDD実装ステップ

#### Step 1: GoogleCalendarRepositoryのテスト
```ruby
# spec/infrastructure/repositories/google_calendar_repository_spec.rb
describe Infrastructure::GoogleCalendarRepository do
  subject(:repository) { Infrastructure::GoogleCalendarRepository.new }
  
  describe '#fetch_events' do
    it 'should fetch events from Google Calendar API' do
      # 失敗するテストを先に書く
    end
  end
end
```

#### Step 2: ConfigurationServiceのテスト
```ruby
# spec/infrastructure/services/configuration_service_spec.rb
describe Infrastructure::ConfigurationService do
  subject(:config) { Infrastructure::ConfigurationService.instance }
  
  describe '#google_client_id' do
    context 'when GOOGLE_CLIENT_ID is set' do
      it 'should return the client ID' do
        # 失敗するテストを先に書く
      end
    end
  end
end
```

---

## Phase 2: Use Cases層の実装

### 🎯 目的
- **ビジネスロジック明確化**: 複数責任の分離
- **エラーハンドリング統一**: FIXME問題の根本解決
- **新機能追加容易化**: 拡張ポイントの明確化

### 2.1 AnalyzeCalendarUseCaseの実装

#### Before: 責任混在
```ruby
# 現在: GoogleCalendarClientに全てが混在
def get_events(start_date, end_date)
  authenticate                              # 認証
  all_events = @service.list_events(...)    # API取得
  attended_events = filter_attended_events(all_events)  # フィルタ
  # + ログ出力
end
```

#### After: 責任分離
```ruby
# lib/calendar_color_mcp/application/use_cases/analyze_calendar_use_case.rb
module Application
  class AnalyzeCalendarUseCase
    def initialize(
      calendar_repository: Infrastructure::GoogleCalendarRepository.new,
      filter_service: Domain::EventFilterService.new,
      analyzer_service: Domain::TimeAnalysisService.new,
      token_manager: TokenManager.instance,
      auth_manager: GoogleCalendarAuthManager.instance
    )
      @calendar_repository = calendar_repository
      @filter_service = filter_service
      @analyzer_service = analyzer_service
      @token_manager = token_manager
      @auth_manager = auth_manager
    end
    
    def execute(start_date:, end_date:, color_filters: nil, user_email:)
      # 1. 認証確認
      ensure_authenticated
      
      # 2. 日付範囲バリデーション
      parsed_start_date, parsed_end_date = validate_date_range(start_date, end_date)
      
      # 3. イベント取得（デバッグログ付き）
      debug_repository = Infrastructure::GoogleCalendarRepositoryLogDecorator.new(@calendar_repository)
      events = debug_repository.fetch_events(parsed_start_date, parsed_end_date)
      
      # 4. フィルタリング適用（Domain::EventFilterService）
      filtered_events = @filter_service.apply_filters(events, color_filters, user_email)
      
      # 5. 時間分析実行（Domain::TimeAnalysisService）
      analysis_result = @analyzer_service.analyze(filtered_events)
      
      analysis_result
    rescue Application::AuthenticationError => e
      handle_authentication_error(e)
    rescue Infrastructure::ExternalServiceError => e
      raise Application::BusinessLogicError, "Calendar service unavailable: #{e.message}"
    rescue Domain::BusinessRuleViolationError => e
      raise Application::ValidationError, "Invalid calendar data: #{e.message}"
    end
  end
end
```

### 2.2 エラーハンドリング標準化

#### 📋 現在の問題
```ruby
# google_calendar_client.rb:88-90 (FIXME: 例外を握りつぶし)
def get_user_email
  calendar_info = @service.get_calendar('primary')
  calendar_info.id
rescue => e
  # FIXME:例外を握りつぶしていいのか？
  logger.debug "User email retrieval error: #{e.message}"
  nil
end
```

#### ✅ 解決策: 層別エラー定義と変換

**各層での適切なエラー定義**:
```ruby
# lib/calendar_color_mcp/application/errors.rb
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

# lib/calendar_color_mcp/infrastructure/errors.rb
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

# lib/calendar_color_mcp/domain/errors.rb
module Domain
  # 基底エラー
  class DomainError < StandardError; end
  
  # ビジネスルール違反エラー（ドメインルール、制約違反関連）
  class BusinessRuleViolationError < DomainError; end
  
  # データ整合性エラー（エンティティ、値オブジェクトの整合性関連）
  class DataIntegrityError < DomainError; end
end

# lib/calendar_color_mcp/interface_adapters/errors.rb
module InterfaceAdapters
  # 基底エラー
  class InterfaceAdapterError < StandardError; end
  
  # プロトコル変換エラー（MCP変換、パラメータ変換関連）
  class ProtocolError < InterfaceAdapterError; end
  
  # レスポンス生成エラー（JSON生成、フォーマット関連）
  class ResponseError < InterfaceAdapterError; end
end
```

**層間エラー変換例**:
```ruby
# Infrastructure → Application（外部サービスエラーをビジネスロジックエラーに変換）
rescue Infrastructure::ExternalServiceError => e
  raise Application::BusinessLogicError, "Calendar service unavailable: #{e.message}"

# Domain → Application（ドメインルール違反を検証エラーに変換）
rescue Domain::BusinessRuleViolationError => e
  raise Application::ValidationError, "Business rule violation: #{e.message}"

# Application → Interface Adapters（アプリケーションエラーをプロトコルエラーに変換）
rescue Application::AuthenticationError => e
  error_response(e.message, auth_url: get_auth_url)
rescue Application::ValidationError => e
  raise InterfaceAdapters::ProtocolError, "Invalid request: #{e.message}"
```

### 2.3 シンプルなキーワード引数アプローチ

```ruby
# Use Caseでのシンプルなパラメータ受け取り
module Application
  class AnalyzeCalendarUseCase
    def execute(start_date:, end_date:, color_filters: nil, user_email:)
      # 日付範囲バリデーション
      parsed_start_date, parsed_end_date = validate_date_range(start_date, end_date)
      
      # ビジネスロジック実行（デバッグログ付き）
      debug_repository = Infrastructure::GoogleCalendarRepositoryLogDecorator.new(@calendar_repository)
      events = debug_repository.fetch_events(parsed_start_date, parsed_end_date)
      filtered_events = @filter_service.apply_filters(events, color_filters, user_email)
      @analyzer_service.analyze(filtered_events)
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

---

## Phase 4: Interface Adapters層

### 🎯 目的
- **MCPツールの薄層化**: ビジネスロジックの移譲
- **統一的なエラーレスポンス**: レスポンス形式の標準化
- **Controller的役割**: リクエスト/レスポンス変換のみ

### 4.1 BaseToolのモジュール名前空間変更

#### Base Tool層のInterface Adapters移行
```ruby
# lib/calendar_color_mcp/tools/base_tool.rb
# Before: CalendarColorMCP::BaseTool
# After: InterfaceAdapters::BaseTool

module InterfaceAdapters
  class BaseTool < MCP::Tool
    include CalendarColorMCP::Loggable
    
    # 既存のメソッドをそのまま移行
    class << self
      protected
      
      def extract_auth_manager(context)
        # 既存の実装
      end
      
      def success_response(data)
        # 既存の実装
      end
      
      def error_response(message)
        ErrorResponseBuilder.new(message)
      end
    end
  end
end
```

### 4.2 ErrorResponseBuilderの簡素化

#### 📋 現在の問題
```ruby
# lib/calendar_color_mcp/tools/base_tool.rb:44-70 (設計決定書で確認済み)
class ErrorResponseBuilder
  def initialize(message)
    @data = { success: false, error: message }
  end
  
  def with(key, value = nil, **data)
    # 複雑なビルダーパターン実装
    if key.is_a?(Hash)
      @data.merge!(key)
    elsif !data.empty?
      @data.merge!(data)
    else
      @data[key] = value
    end
    self
  end
  
  def build
    MCP::Tool::Response.new([{
      type: "text",
      text: @data.to_json
    }])
  end
end
```

**問題点**:
- シンプルなエラーレスポンスに対する過度な抽象化
- ビルダーパターンの実装が複雑で、使用箇所も限定的
- メンテナンスコストが機能の価値を上回る

#### ✅ 解決策: 標準エラーレスポンス採用

**1. BaseTool の InterfaceAdapters モジュールへの移行**
```ruby
# lib/calendar_color_mcp/tools/base_tool.rb (リファクタ後)
module InterfaceAdapters
  class BaseTool < MCP::Tool
    include CalendarColorMCP::Loggable
    
    class << self
      protected
      
      def success_response(data)
        response_data = {
          success: true
        }.merge(data)

        MCP::Tool::Response.new([{
          type: "text",
          text: response_data.to_json
        }])
      end
      
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
    end
  end
end
```

**2. ErrorResponseBuilderの完全削除**
```ruby
# 削除対象
# - class ErrorResponseBuilder
# - 関連するビルダーパターンメソッド
# - 複雑な with() チェーンメソッド
```

**簡素化の利点**:
- ✅ **コード量削減**: 複雑なビルダークラスを廃止し、シンプルなヘルパーメソッドに置換
- ✅ **保守性向上**: エラーレスポンス形式が一目で理解可能
- ✅ **統一性確保**: 全ツールで同一のエラーレスポンス形式を使用
- ✅ **拡張性維持**: additional_dataパラメータで必要時の拡張をサポート

### 4.2 MCPツールのController化

#### Before: ビジネスロジック含有
```ruby
# 現在: AnalyzeCalendarTool内にビジネスロジック
class AnalyzeCalendarTool < BaseTool
  def call(start_date:, end_date:, **context)
    # 50行のビジネスロジック
    # 認証チェック、データ取得、分析処理...
  end
end
```

#### After: 薄い層（Controller的役割）
```ruby
# lib/calendar_color_mcp/interface_adapters/tools/analyze_calendar_tool.rb (リファクタ後)
module InterfaceAdapters
  class AnalyzeCalendarTool < BaseTool
    def call(start_date:, end_date:, include_colors: nil, exclude_colors: nil, **context)
      # 1. パラメータ変換（日付バリデーション含む）
      color_filters = build_color_filters(include_colors, exclude_colors)
      user_email = extract_user_email(context)
      
      # 2. Use Case実行
      use_case = Application::AnalyzeCalendarUseCase.new(
        token_manager: extract_token_manager(context),
        auth_manager: extract_auth_manager(context)
      )
      
      result = use_case.execute(
        start_date: start_date,
        end_date: end_date,
        color_filters: color_filters,
        user_email: user_email
      )
      
      # 3. レスポンス変換
      success_response(result.to_hash)
    rescue Application::AuthenticationError => e
      auth_url = extract_auth_manager(context).get_auth_url
      error_response(e.message, auth_url: auth_url)
    rescue Application::ValidationError => e
      error_response("Invalid parameters: #{e.message}")
    rescue Application::BusinessLogicError => e
      error_response("Calendar access failed: #{e.message}")
    rescue InterfaceAdapters::ProtocolError => e
      error_response("Request format error: #{e.message}")
    end
  end
end
```

---

## Phase 1: Domain層の確立

### 🎯 目的
- **ドメインロジック保護**: ビジネスルールの明確化
- **長期的拡張性**: 新機能追加の基盤作り
- **値オブジェクト**: 不変性と型安全性の確保

### 1.1 エンティティの作成

**ColorConstants移行（最優先）**
```ruby
# lib/calendar_color_mcp/domain/entities/color_constants.rb
module Domain
  class ColorConstants
    COLOR_NAMES = {
      1 => '薄紫', 2 => '緑', 3 => '紫', 4 => '赤', 5 => '黄',
      6 => 'オレンジ', 7 => '水色', 8 => '灰色', 9 => '青',
      10 => '濃い緑', 11 => '濃い赤'
    }.freeze

    NAME_TO_ID = COLOR_NAMES.invert.freeze
    DEFAULT_COLOR_ID = 9

    def self.name_to_id
      NAME_TO_ID
    end

    def self.default_color_id
      DEFAULT_COLOR_ID
    end

    def self.color_names_array
      COLOR_NAMES.values
    end

    def self.valid_color_id?(id)
      COLOR_NAMES.key?(id)
    end

    def self.color_name(id)
      COLOR_NAMES[id]
    end
  end
end
```

**CalendarEventエンティティ作成**
```ruby
# lib/calendar_color_mcp/domain/entities/calendar_event.rb
module Domain
  class CalendarEvent
    attr_reader :summary, :start_time, :end_time, :color_id, :attendees, :organizer
    
    def initialize(summary:, start_time:, end_time:, color_id:, attendees: [], organizer: nil)
      @summary = summary
      @start_time = start_time
      @end_time = end_time
      @color_id = color_id
      @attendees = attendees
      @organizer = organizer
      
      validate_time_range
    end
    
    def duration_hours
      return 0 unless @start_time && @end_time
      (@end_time - @start_time) / 3600.0
    end
    
    def attended_by?(user_email)
      return true if organized_by_user?
      return true if private_event?
      
      user_attendee = find_user_attendee(user_email)
      user_attendee&.accepted?
    end
    
    def color_name
      Domain::ColorConstants::COLOR_NAMES[@color_id] || Domain::ColorConstants::DEFAULT_COLOR_NAME
    end
    
    private
    
    def organized_by_user?
      @organizer&.self
    end
    
    def private_event?
      @attendees.nil? || @attendees.empty?
    end
    
    def find_user_attendee(user_email)
      @attendees&.find { |attendee| attendee.email == user_email || attendee.self }
    end
    
    def validate_time_range
      return unless @start_time && @end_time
      if @end_time <= @start_time
        raise Domain::BusinessRuleViolationError, "End time must be after start time"
      end
    end
  end
end
```

### 1.2 値オブジェクトの作成

**注意**: TimeSpan値オブジェクトは削除されました。日付範囲のバリデーションはApplication層のAnalyzeCalendarUseCase内で直接実行されます。これはYAGNI原則に従い、単一Use Case専用の機能に対する過度な抽象化を避けるためです。

### 1.3 ドメインサービス作成

#### EventFilterService（ビジネスルールフィルタリング）

**重要: EventFilterServiceはDomain層に配置**

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

**Domain層配置の根拠**:
- **参加イベント判定**: 主催者/招待承諾/プライベートイベントの判定はビジネスルール
- **色フィルタリング**: 色IDによる包含/除外選択もビジネスルール
- **再利用性**: 他のUse Caseでも同じフィルタリングルールを使用
- **依存関係逆転原則**: ApplicationがDomainサービスに依存する正しい方向

**Infrastructure層との責任分離**:
- **Domain層**: ビジネスルールに基づくフィルタリング
- **Infrastructure層**: 技術的詳細（API変換、設定管理）のみ

#### TimeAnalysisService（既存TimeAnalyzerの移行）

**重要: 既存TimeAnalyzerをDomain層に移行**

```ruby
# lib/calendar_color_mcp/domain/services/time_analysis_service.rb
module Domain
  class TimeAnalysisService
    include CalendarColorMCP::Loggable

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
      color_data = {}

      events.each do |event|
        color_id = event.color_id&.to_i || Domain::ColorConstants.default_color_id
        color_name = Domain::ColorConstants.color_name(color_id) || "不明 (#{color_id})"

        color_data[color_name] ||= {
          total_hours: 0.0,
          event_count: 0,
          events: []
        }

        duration = calculate_duration(event)
        color_data[color_name][:total_hours] += duration
        color_data[color_name][:event_count] += 1
        color_data[color_name][:events] << {
          title: event.summary || '（タイトルなし）',
          duration: duration,
          start_time: format_event_time(event)
        }
      end

      # 時間順でソート
      color_data = color_data.sort_by { |_, data| -data[:total_hours] }.to_h

      # 時間を四捨五入
      color_data.each do |_, data|
        data[:total_hours] = data[:total_hours].round(2)
      end

      color_data
    end

    def calculate_duration(event)
      # 既存TimeAnalyzerのcalculate_durationロジックを移行
    end

    def generate_summary(color_breakdown, event_count)
      # 既存TimeAnalyzerのgenerate_summaryロジックを移行
    end

    def format_event_time(event)
      # 既存TimeAnalyzerのformat_event_timeロジックを移行
    end
  end
end
```

**責任分離の明確化**:
- **Domain::EventFilterService**: 参加イベント判定と色フィルタリング
- **Domain::TimeAnalysisService**: フィルタリング済みイベントの時間分析
- **Application::AnalyzeCalendarUseCase**: 両サービスの協調

**移行の利点**:
- シグネチャ統一: `analyze(filtered_events)`で`AnalyzeCalendarUseCase`との整合性確保
- 色フィルタリング責任の分離: `TimeAnalyzer`から複雑な色フィルタロジックを除去
- 既存ロジック保持: 時間計算とサマリー生成の実績あるロジックを維持


---

## Phase 5: 統合とテスト改善

### 🎯 目的
- **全コンポーネント統合**: 各Phaseの統合確認
- **テスト戦略改善**: Use Case単位テストの充実
- **FIXME完全解決**: 全技術債務の解決確認

### 5.1 テスト戦略の改善

#### Use Caseレベルでのテスト
```ruby
# spec/application/use_cases/analyze_calendar_use_case_spec.rb
describe Application::AnalyzeCalendarUseCase do
  let(:mock_calendar_repository) { instance_double(Infrastructure::GoogleCalendarRepository) }
  let(:mock_filter_service) { instance_double(Domain::EventFilterService) }
  let(:mock_analyzer_service) { instance_double(TimeAnalyzer) }
  let(:mock_token_manager) { TokenManager.instance }  # 実際のSingleton使用
  let(:mock_auth_manager) { GoogleCalendarAuthManager.instance }  # 実際のSingleton使用
  
  subject(:use_case) do 
    Application::AnalyzeCalendarUseCase.new(
      calendar_repository: mock_calendar_repository,
      filter_service: mock_filter_service,
      analyzer_service: mock_analyzer_service,
      token_manager: mock_token_manager,
      auth_manager: mock_auth_manager
    )
  end
  
  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }
  let(:user_email) { 'test@example.com' }
  
  describe '#execute' do
    context 'when user is authenticated' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(true)
        allow(mock_calendar_repository).to receive(:fetch_events).and_return([mock_event])
        allow(mock_filter_service).to receive(:apply_filters).and_return([mock_event])
        allow(mock_analyzer_service).to receive(:analyze).and_return(mock_analysis_result)
      end
      
      it 'should analyze calendar events successfully' do
        result = use_case.execute(
          start_date: start_date,
          end_date: end_date,
          user_email: user_email
        )
        
        expect(result).to be_success
        expect(mock_calendar_repository).to have_received(:fetch_events).with(
          start_date, 
          end_date
        )
      end
    end
    
    context 'when user is not authenticated' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(false)
      end
      
      it 'should raise AuthenticationRequiredError' do
        expect { 
          use_case.execute(
            start_date: start_date,
            end_date: end_date,
            user_email: user_email
          ) 
        }.to raise_error(AuthenticationRequiredError)
      end
    end
  end
end
```

### 5.2 統合テストの維持

```ruby
# spec/integration/calendar_flow_spec.rb
describe "Calendar Analysis Flow" do
  # 既存の統合テストを維持
  # リアーキテクチャ後も同じ動作を保証
end
```

### 5.3 FIXME解決確認

- ✅ **server.rb:47**: Use Case層での統一エラーハンドリング実装
- ✅ **google_calendar_client.rb:21**: Repository+UseCase分離完了
- ✅ **google_calendar_client.rb:88**: 適切な例外処理実装
- ✅ **base_tool.rb:27**: 標準エラーレスポンス採用

---

## 重要な設計決定

### 🔄 Singletonパターンの継続

#### 継続するもの
```ruby
# 適切なドメイン表現として継続
TokenManager.instance           # ファイル競合回避、リソース保護
GoogleCalendarAuthManager.instance  # 認証状態統一、設定一元管理
ConfigurationService.instance   # 新規追加：環境変数管理一元化
```

#### 依存性注入との共存
```ruby
module Application
  class AnalyzeCalendarUseCase
    def initialize(
      calendar_repository: Infrastructure::GoogleCalendarRepository.new,     # 注入可能
      token_repository: TokenManager.instance,              # Singleton
      auth_service: GoogleCalendarAuthManager.instance,     # Singleton
      config_service: Infrastructure::ConfigurationService.instance         # Singleton
    )
      # テスト容易性とドメイン整合性の両立
    end
  end
end
```

### 📋 TDD実施方針

各段階で以下のサイクルを徹底:

1. **🔴 Red**: 失敗するテストを書く
2. **🟢 Green**: テストを通過する最小限の実装
3. **🔵 Refactor**: リファクタリング実行
4. **✅ Verify**: テスト成功の確認

```ruby
# TDD Example: ConfigurationService
# spec/infrastructure/services/configuration_service_spec.rb
describe Infrastructure::ConfigurationService do
  # 1. Red: 失敗するテストを先に書く
  it 'should raise error when GOOGLE_CLIENT_ID is missing' do
    expect { Infrastructure::ConfigurationService.instance.google_client_id }.to raise_error
  end
  
  # 2. Green: 最小限の実装
  # 3. Refactor: リファクタリング
  # 4. Verify: テスト確認
end
```

---

## ディレクトリ構造設計

### 最終的なディレクトリ構造

```
lib/calendar_color_mcp/
├── domain/                          # Domain層
│   ├── entities/
│   │   ├── calendar_event.rb       # カレンダーイベントエンティティ
│   │   ├── auth_token.rb           # 認証トークンエンティティ
│   │   ├── event_filter.rb         # イベントフィルタ値オブジェクト
│   │   └── color_constants.rb      # 色IDと色名のマッピング（既存移行）
│   └── services/
│       ├── time_analysis_service.rb        # 時間分析（既存TimeAnalyzerから移行）
│       ├── event_filter_service.rb         # イベントフィルタリング（ビジネスルール）
│       └── event_duration_calculation_service.rb # イベント期間計算
├── application/                     # Application層
│   ├── use_cases/
│   │   ├── analyze_calendar_use_case.rb # カレンダー分析Use Case
│   │   ├── authenticate_user_use_case.rb# 認証Use Case
│   │   ├── check_auth_status_use_case.rb# 認証状態確認Use Case
│   │   └── filter_events_by_color_use_case.rb # 色別フィルタリングUse Case
│   └── services/
│       └── calendar_orchestration_service.rb # 複数UseCase調整（段階的実装）
├── interface_adapters/              # Interface Adapters層
│   └── tools/
│       ├── analyze_calendar_tool.rb # Controller化
│       ├── start_auth_tool.rb       # Controller化
│       ├── check_auth_status_tool.rb# Controller化
│       ├── complete_auth_tool.rb    # Controller化
│       └── base_tool.rb             # 既存維持
├── infrastructure/                  # Infrastructure層
│   ├── repositories/
│   │   ├── google_calendar_repository.rb   # Google Calendar API Repository (GoogleCalendarRepositoryLogDecoratorを含む)
│   │   └── token_file_repository.rb        # Token File Repository
│   └── services/
│       └── configuration_service.rb        # 設定管理サービス
├── calendar_color_mcp.rb           # ルートファイル
├── color_constants.rb              # 段階的廃止予定
├── color_filter_manager.rb         # 段階的廃止予定
├── errors.rb                       # 段階的廃止予定
├── google_calendar_auth_manager.rb # 部分修正
├── google_calendar_client.rb       # 段階的廃止予定
├── loggable.rb                     # 既存維持
├── logger_manager.rb               # 既存維持
├── server.rb                       # 部分修正
├── time_analyzer.rb                # 段階的廃止予定（Domain::TimeAnalysisServiceに移行）
└── token_manager.rb                # 既存維持

# モジュール名前空間設計（簡潔化）
# Domain::CalendarEvent
# Domain::ColorConstants               # 既存ColorConstantsから移行
# Domain::TimeAnalysisService          # 既存TimeAnalyzerから移行
# Domain::EventFilterService           # ビジネスルール
# Application::AnalyzeCalendarUseCase  
# Infrastructure::GoogleCalendarRepository
# InterfaceAdapters::AnalyzeCalendarTool
```

### 段階的移行戦略

```
Phase 3: infrastructure/services/ + infrastructure/repositories/ 作成
Phase 2: application/use_cases/ + application/services/ 作成  
Phase 4: interface_adapters/tools/ リファクタリング
Phase 1: domain/entities/ + domain/services/ 作成
Phase 5: 統合テスト・既存ファイル最適化
```

---

## FIXME解決リスト

### 🔧 技術債務の完全解決

| 場所 | 問題 | 解決方法 | Phase |
|------|------|----------|-------|
| **server.rb:47** | 呼び出し失敗時のエラーハンドリング不足 | Use Case層で統一エラーハンドリング実装 | Phase 2 |
| **google_calendar_client.rb:21** | ビジネスロジック混在 | Repository+UseCase+Service分離 | Phase 3 |
| **google_calendar_client.rb:88** | 例外の握りつぶし | 適切な例外処理とログ記録実装 | Phase 2 |
| **base_tool.rb:27** | ビルダーパターンの必要性 | 標準エラーレスポンス採用で簡素化 | Phase 4 |
| **errors.rb** | 層の責任混在、依存関係逆転原則違反 | 各層への適切なエラー分散配置 | Phase 2.5 |

### 解決後の状態

#### ✅ server.rb:47 解決
```ruby
# Before: エラーハンドリング不足
def run
  transport = MCP::Server::Transports::StdioTransport.new(@server)
  transport.open  # FIXME: エラーハンドリングがない
end

# After: 適切なエラーハンドリング
def run
  transport = MCP::Server::Transports::StdioTransport.new(@server)
  transport.open
rescue => e
  logger.error "Server startup failed: #{e.message}"
  logger.error "Backtrace: #{e.backtrace}"
  raise ServerStartupError, "Failed to start MCP server: #{e.message}"
end
```

#### ✅ google_calendar_client.rb:21 解決
```ruby
# Before: 60行の巨大メソッド（4つの責任混在）
def get_events(start_date, end_date)
  # 認証・API・フィルタ・ログが混在
end

# After: 責任分離
module Application
  class AnalyzeCalendarUseCase
    def execute(start_date:, end_date:, color_filters: nil, user_email:)
      debug_repository = Infrastructure::GoogleCalendarRepositoryLogDecorator.new(@calendar_repository)
      events = debug_repository.fetch_events(start_date, end_date)      # API責任（デバッグログ付き）
      filtered_events = @filter_service.apply_filters(events, color_filters, user_email) # フィルタ責任（Domain::EventFilterService）
      @analyzer_service.analyze(filtered_events)           # 分析責任（Domain::TimeAnalysisService）
    end
  end
end
```

---

## 期待効果

### 📈 段階別効果測定

#### Phase 3完了時（即座の効果）
- ✅ **60行の巨大メソッド解決**: 責任分離による可読性向上
- ✅ **重複コード削減**: 環境変数検証の一元化（2箇所→1箇所）
- ✅ **テストの簡素化**: Mock対象の明確化
- ✅ **保守性向上**: 変更影響範囲の局所化

#### Phase 2完了時（中期的効果）
- ✅ **ビジネスロジック明確化**: Use Caseでのロジック集約
- ✅ **エラーハンドリング統一**: 層別エラー定義による一貫性
- ✅ **依存関係逆転原則遵守**: 層間エラー変換の適切な実装
- ✅ **新機能追加容易化**: 拡張ポイントの明確化
- ✅ **技術債務解決**: 全FIXME問題（errors.rb含む）の根本解決
- ✅ **個別Use Case確立**: CalendarOrchestrationServiceは必要性が明確になった段階で段階的導入

#### Phase 4完了時（統合効果）
- ✅ **MCPツール薄層化**: Controller的役割への明確化
- ✅ **レスポンス統一**: 一貫したエラーレスポンス形式
- ✅ **依存関係明確化**: 注入可能な設計への移行

#### Phase 1完了時（長期的効果）
- ✅ **ドメインロジック保護**: エンティティでのビジネスルール表現
- ✅ **型安全性確保**: 値オブジェクトによる不変性
- ✅ **拡張性確保**: 新ドメインルール追加の基盤

#### Phase 5完了時（全体効果）
- ✅ **テスト戦略改善**: Use Case単位での網羅的テスト
- ✅ **品質保証**: 全機能の動作保証
- ✅ **技術債務ゼロ**: 全FIXME解決の確認

### 📊 定量的指標

| 指標 | Before | After | 改善率 |
|------|--------|-------|--------|
| **最大メソッド行数** | 60行 | 15行以下 | 75%削減 |
| **重複コード箇所** | 2箇所 | 0箇所 | 100%削減 |
| **FIXME数** | 5個 | 0個 | 100%解決 |
| **テスト実行時間** | 測定 | 測定予定 | 改善予定 |
| **クラス責任数** | 4個/クラス | 1個/クラス | 単一責任達成 |

---

## 実装開始準備

### ✅ 前提条件確認

- [x] 現在のテストスイートが全て成功している
- [x] MCPサーバーが正常に動作している  
- [x] Singletonパターンの妥当性が確認されている
- [x] 段階的移行戦略が明確である

### 🚀 実装開始手順

1. **Phase 3開始**: `TodoWrite`でタスク管理開始
2. **TDDサイクル**: 各コンポーネントで失敗テスト→実装→リファクタ
3. **既存テスト維持**: 各Phase完了時に全テスト成功確認
4. **段階的統合**: 各Phaseで動作確認
5. **最終統合**: Phase 5で全体統合テスト

### 🎯 CalendarOrchestrationServiceの段階的実装方針

**段階1: 個別Use Caseの確立を最優先**
```ruby
# まず各Use Caseを独立して実装
module Application
  class AnalyzeCalendarUseCase; end    # Domain::TimeAnalysisService使用
  class AuthenticateUserUseCase; end
  class CheckAuthStatusUseCase; end
  class FilterEventsByColorUseCase; end  # Domain::EventFilterService使用
end
```

**Phase 1実装順序の更新**:
1. **Domain::TimeAnalysisService作成**: 既存TimeAnalyzerから移行（最優先）
2. **Domain::EventFilterService作成**: 色フィルタリング分離
3. **Application::AnalyzeCalendarUseCase統合**: 両サービスの協調
4. **既存TimeAnalyzer段階的廃止**: 新サービスへの完全移行確認

**段階2: 必要性が明確になった時点でOrchestration導入**
- 複数Use Case間の複雑な調整が実際に必要になった場合のみ実装
- YAGNI原則（You Aren't Gonna Need It）に従い、過度な抽象化を避ける
- 現在のシンプルなワークフローでは個別Use Caseで十分対応可能

### 🎯 成功基準

- ✅ 全既存テストが成功し続ける
- ✅ 新機能追加が容易になる
- ✅ コードの可読性・保守性が向上する
- ✅ 技術債務（FIXME）が完全解決される
- ✅ MCPサーバーの動作が保証される

---

このリアーキテクチャ計画により、**現在のコードベースの利点を活かしつつ、クリーンアーキテクチャの恩恵を段階的に享受**し、長期的な保守性と拡張性を確保します。
