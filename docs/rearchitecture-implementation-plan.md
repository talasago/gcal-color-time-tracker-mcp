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
│   │   └── token_repository.rb             # Token Repository（Phase 6でTokenManagerをここに移行）
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
└── token_manager.rb                # Phase 6でInfrastructure::TokenRepositoryに移行予定

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

## Phase 6: 認証アーキテクチャの改善

### 🎯 目的
- **GoogleCalendarAuthManagerの責務分離**: OAuth通信とビジネスロジックの明確な分離
- **Singletonパターンの除去**: テスト容易性と依存性注入の改善
- **Infrastructure層への適切な配置**: OAuth API通信の責任明確化

### 6.1 現在の問題分析

#### 📋 GoogleCalendarAuthManagerの責務混在
```ruby
# lib/calendar_color_mcp/google_calendar_auth_manager.rb (現状)
class GoogleCalendarAuthManager
  include Singleton
  
  def get_auth_url
    # 1. 設定値取得責任
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

**問題点**:
- **責務混在**: OAuth API通信とビジネスロジックが混在
- **Singleton依存**: テスト時のモック困難
- **依存関係不明確**: TokenManagerとの関係が不明確
- **Infrastructure層の概念不在**: Google OAuth APIとの通信が適切に抽象化されていない

### 6.2 解決策: 責任分離と層別配置

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

#### Application::AuthenticationUseCase（既存の強化）
```ruby
# lib/calendar_color_mcp/application/use_cases/authentication_use_case.rb
module Application
  class AuthenticationUseCase
    def initialize(
      oauth_service: Infrastructure::GoogleOAuthService.new,
      token_manager: CalendarColorMCP::TokenManager.instance
    )
      @oauth_service = oauth_service
      @token_manager = token_manager
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
      @token_manager.save_credentials(credentials)
      
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
        authenticated: @token_manager.token_exist?,
        token_file_exists: @token_manager.token_file_exists?
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

### 6.3 Interface Adaptersの更新

#### StartAuthTool（Use Case使用への変更）
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
```

#### CheckAuthStatusTool（Use Case使用への変更）
```ruby
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

### 6.4 Server.rbでの依存性注入

#### server_contextの更新
```ruby
# lib/calendar_color_mcp/server.rb (該当部分の更新)
def setup_server_context
  oauth_service = Infrastructure::GoogleOAuthService.new
  calendar_repository = Infrastructure::GoogleCalendarRepositoryLogDecorator.new(
    Infrastructure::GoogleCalendarRepository.new
  )
  
  {
    oauth_service: oauth_service,                              # 新規追加
    calendar_repository: calendar_repository,
    token_manager: CalendarColorMCP::TokenManager.instance    # 既存維持
    # auth_manager: GoogleCalendarAuthManagerは削除
  }
end
```

### 6.5 GoogleCalendarAuthManagerの段階的廃止

#### 移行ステップ
1. **Infrastructure::GoogleOAuthService作成**
2. **Application::AuthenticationUseCase強化**
3. **Interface Adaptersの更新**
4. **server.rbからGoogleCalendarAuthManager参照削除**
5. **テスト更新**
6. **GoogleCalendarAuthManager完全削除**

#### 影響範囲の確認
```ruby
# 現在GoogleCalendarAuthManagerを使用している箇所
# - StartAuthTool
# - CheckAuthStatusTool  
# - AnalyzeCalendarTool（認証エラー時のauth_url取得）
# - server.rb（server_context設定）
```

### 6.6 テスト戦略

#### Infrastructure::GoogleOAuthServiceのテスト
```ruby
# spec/infrastructure/services/google_oauth_service_spec.rb
describe Infrastructure::GoogleOAuthService do
  subject(:oauth_service) { Infrastructure::GoogleOAuthService.new(config_service: mock_config) }
  
  let(:mock_config) do
    instance_double(Infrastructure::ConfigurationService).tap do |mock|
      allow(mock).to receive(:google_client_id).and_return('test_client_id')
      allow(mock).to receive(:google_client_secret).and_return('test_client_secret')
    end
  end
  
  describe '#generate_auth_url' do
    it 'should generate valid OAuth URL' do
      url = oauth_service.generate_auth_url
      expect(url).to include('accounts.google.com')
      expect(url).to include('test_client_id')
    end
  end
  
  describe '#exchange_code_for_token' do
    it 'should exchange authorization code for access token' do
      # HTTP mocker使用によるGoogle OAuth API mocking
    end
  end
end
```

#### Application::AuthenticationUseCaseのテスト強化
```ruby
# spec/application/use_cases/authentication_use_case_spec.rb
describe Application::AuthenticationUseCase do
  subject(:use_case) do
    Application::AuthenticationUseCase.new(
      oauth_service: mock_oauth_service,
      token_manager: mock_token_manager
    )
  end
  
  let(:mock_oauth_service) { instance_double(Infrastructure::GoogleOAuthService) }
  let(:mock_token_manager) { instance_double(CalendarColorMCP::TokenManager) }
  
  describe '#start_authentication' do
    context 'when OAuth service works correctly' do
      before do
        allow(mock_oauth_service).to receive(:generate_auth_url)
          .and_return('https://accounts.google.com/oauth2/auth?...')
      end
      
      it 'should return auth URL and instructions' do
        result = use_case.start_authentication
        
        expect(result[:auth_url]).to include('accounts.google.com')
        expect(result[:instructions]).to include('ブラウザで')
      end
    end
    
    context 'when OAuth service fails' do
      before do
        allow(mock_oauth_service).to receive(:generate_auth_url)
          .and_raise(Infrastructure::ExternalServiceError, 'OAuth API error')
      end
      
      it 'should raise Application::AuthenticationError' do
        expect { use_case.start_authentication }
          .to raise_error(Application::AuthenticationError, /認証開始に失敗/)
      end
    end
  end
  
  describe '#complete_authentication' do
    let(:auth_code) { 'valid_auth_code_123' }
    let(:mock_credentials) { instance_double(Signet::OAuth2::Client) }
    
    context 'when authentication succeeds' do
      before do
        allow(mock_oauth_service).to receive(:exchange_code_for_token)
          .with(auth_code).and_return(mock_credentials)
        allow(mock_token_manager).to receive(:save_credentials)
          .with(mock_credentials)
      end
      
      it 'should complete authentication successfully' do
        result = use_case.complete_authentication(auth_code)
        
        expect(result[:success]).to be true
        expect(result[:message]).to include('認証が完了')
        expect(mock_token_manager).to have_received(:save_credentials)
      end
    end
    
    context 'when auth code is invalid' do
      it 'should raise validation error for empty code' do
        expect { use_case.complete_authentication('') }
          .to raise_error(Application::ValidationError, /認証コードが入力されていません/)
      end
    end
  end
  
  describe '#check_authentication_status' do
    context 'when user is authenticated' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(true)
        allow(mock_token_manager).to receive(:token_file_exists?).and_return(true)
      end
      
      it 'should return authenticated status' do
        result = use_case.check_authentication_status
        
        expect(result[:authenticated]).to be true
        expect(result[:token_file_exists]).to be true
      end
    end
  end
end
```

### 6.7 TDD実装ステップ

#### Step 1: Infrastructure::GoogleOAuthService
1. **🔴 Red**: テスト作成（認証URL生成失敗）
2. **🟢 Green**: 最小実装（固定URL返却）
3. **🔵 Refactor**: OAuth client実装
4. **✅ Verify**: テスト成功確認

#### Step 2: Application::AuthenticationUseCase強化
1. **🔴 Red**: テスト作成（Use Case統合失敗）
2. **🟢 Green**: OAuth service使用実装
3. **🔵 Refactor**: エラーハンドリング改善
4. **✅ Verify**: テスト成功確認

#### Step 3: Interface Adapters更新
1. **🔴 Red**: テスト作成（新Use Case使用失敗）
2. **🟢 Green**: Use Case呼び出し実装
3. **🔵 Refactor**: エラーレスポンス統一
4. **✅ Verify**: 統合テスト成功確認

#### Step 4: GoogleCalendarAuthManager除去
1. **🔴 Red**: 既存テスト失敗確認
2. **🟢 Green**: 新アーキテクチャでのテスト修正
3. **🔵 Refactor**: 未使用コード完全削除
4. **✅ Verify**: 全テスト成功確認

### 6.8 TokenManagerのInfrastructure層移行

#### 📋 TokenManagerの現在の問題と移行理由
```ruby
# lib/calendar_color_mcp/token_manager.rb (現状)
class TokenManager
  include Singleton
  
  def save_credentials(credentials)
    # ファイルI/O操作（Infrastructure層の責任）
    File.write(@token_file_path, token_data.to_json)
  end
  
  def load_credentials
    # 外部ライブラリ依存（Infrastructure層の責任）
    config = Infrastructure::ConfigurationService.instance
    credentials = Google::Auth::UserRefreshCredentials.new(...)
  end
end
```

**Infrastructure層移行の根拠**:
- **技術的責任**: ファイルI/O、外部ライブラリ操作
- **設定サービス依存**: Infrastructure::ConfigurationServiceを既に使用
- **クリーンアーキテクチャ整合性**: 技術的詳細はInfrastructure層に配置

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

#### Phase 6でのTokenManager移行ステップ

1. **Infrastructure::TokenRepository作成**（Singletonパターン）
2. **Application::AuthenticationUseCase更新**: TokenRepository.instanceを使用
3. **server.rbの依存性注入更新**: TokenRepositoryに変更
4. **テスト更新**: 新アーキテクチャでのテスト実装（Singleton考慮）
5. **TokenManager段階的廃止**: 旧コード除去

#### Application::AuthenticationUseCaseでの使用例
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
    
    def complete_authentication(auth_code)
      credentials = @oauth_service.exchange_code_for_token(auth_code)
      @token_repository.save_credentials(credentials)  # 安全なSingleton操作
      
      {
        success: true,
        message: "認証が完了しました"
      }
    end
  end
end
```

#### server.rbでの依存性注入更新
```ruby
# lib/calendar_color_mcp/server.rb (該当部分の更新)
def setup_server_context
  {
    oauth_service: Infrastructure::GoogleOAuthService.new,
    calendar_repository: Infrastructure::GoogleCalendarRepositoryLogDecorator.new(
      Infrastructure::GoogleCalendarRepository.new
    ),
    token_repository: Infrastructure::TokenRepository.instance  # TokenManagerから移行
    # auth_manager: GoogleCalendarAuthManagerは段階的に削除
  }
end
```

### 6.9 期待効果

#### 認証・トークン管理の統合的改善
- ✅ **OAuth API通信**: Infrastructure::GoogleOAuthService
- ✅ **認証ビジネスロジック**: Application::AuthenticationUseCase  
- ✅ **トークン管理**: Infrastructure::TokenRepository（TokenManagerから移行）
- ✅ **プロトコル変換**: InterfaceAdapters::*Tool

#### 依存性注入の完全な改善
- ✅ **テスト容易性**: 全コンポーネントでSingletonからの脱却
- ✅ **モック可能性**: 各コンポーネントの独立テスト
- ✅ **設定管理統一**: ConfigurationService使用

#### アーキテクチャ整合性の完全実現
- ✅ **層間依存関係**: Application → Infrastructure（正しい方向）
- ✅ **エラー変換**: Infrastructure → Application → Interface Adapters
- ✅ **単一責任原則**: 各クラスが明確な責任を持つ
- ✅ **Infrastructure層の完全確立**: 全技術的詳細の適切な配置

### 6.10 GoogleCalendarRepositoryのDomainオブジェクト変換

#### 📋 Clean Architecture違反の解決

**Phase 6.10の追加目的**:
- **Infrastructure層でのDomain変換実装**: GoogleCalendarRepository#fetch_eventsをClean Architecture準拠に修正
- **Domain層のGoogle API依存除去**: EventFilterServiceとTimeAnalysisServiceの外部API依存を完全除去
- **レイヤー境界の明確化**: Infrastructure層の責任としてのDomainオブジェクト変換

#### 実装ステップ

**Step 1: Domain ValueObject作成**
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

    def declined?
      @response_status == 'declined'
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

**Step 2: GoogleCalendarRepository変換実装**
```ruby
# lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository.rb
module Infrastructure
  class GoogleCalendarRepository
    def fetch_events(start_date, end_date)
      # 既存のAPI呼び出し処理
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
      else
        nil
      end
    end

    def extract_end_time(api_event)
      if api_event.end.date_time
        api_event.end.date_time
      elsif api_event.end.date
        Date.parse(api_event.end.date).to_time
      else
        nil
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

    def convert_organizer(api_organizer)
      return nil unless api_organizer
      
      Domain::Organizer.new(
        email: api_organizer.email,
        display_name: api_organizer.display_name,
        self: api_organizer.self || false
      )
    end
  end
end
```

**Step 3: Domain::CalendarEvent#attended_by?メソッド修正**
```ruby
# lib/calendar_color_mcp/domain/entities/calendar_event.rb
def attended_by?(user_email)
  return true if organized_by_user?
  return true if private_event?

  user_attendee = find_user_attendee(user_email)
  return false unless user_attendee
  user_attendee.accepted?  # Domain::Attendeeのメソッドを使用
end

private

def organized_by_user?
  @organizer&.self  # Domain::Organizerのメソッドを使用
end

def find_user_attendee(user_email)
  @attendees&.find { |attendee| attendee.email == user_email || attendee.self }
end
```

**Step 4: Domain::TimeAnalysisService修正**
```ruby
# lib/calendar_color_mcp/domain/services/time_analysis_service.rb
def calculate_duration(event)
  # CalendarEventのduration_hoursメソッドを使用
  event.duration_hours
end

def format_event_time(event)
  if event.start_time
    if event.start_time.hour == 0 && event.start_time.min == 0
      "#{event.start_time.strftime('%Y-%m-%d')} (All-day)"
    else
      event.start_time.strftime('%Y-%m-%d %H:%M')
    end
  else
    'Unknown time'
  end
end
```

#### Phase 6.10のTDD実装ステップ

1. **🔴 Red**: Domain::AttendeeとOrganizerのテスト作成
2. **🟢 Green**: ValueObjectの最小実装
3. **🔴 Red**: GoogleCalendarRepositoryの変換テスト作成
4. **🟢 Green**: convert_to_domain_event実装
5. **🔴 Red**: Domain層のGoogle API依存除去テスト
6. **🟢 Green**: EventFilterServiceとTimeAnalysisServiceの修正
7. **🔵 Refactor**: 既存テストの統合確認
8. **✅ Verify**: 全テストの成功確認

#### 期待効果

- ✅ **Clean Architecture完全準拠**: Infrastructure層からDomainオブジェクトを返す正しいアーキテクチャ
- ✅ **Domain層の純粋性**: Google API依存の完全除去
- ✅ **変更影響の局所化**: Google API変更時の影響をInfrastructure層に限定
- ✅ **テスト容易性向上**: Domain層のテストでGoogle API mockが不要
- ✅ **コードの保守性向上**: 責任境界の明確化とレイヤー間結合の削減

#### Application層への影響

**変更なし**: AnalyzeCalendarUseCaseは同じインターフェースでDomain::CalendarEvent配列を受け取るため、修正不要。

```ruby
# 変更前後で同じ動作
events = @calendar_repository.fetch_events(parsed_start_date, parsed_end_date)
filtered_events = @filter_service.apply_filters(events, color_filters, user_email)
@analyzer_service.analyze(filtered_events)
```

---

このリアーキテクチャ計画により、**現在のコードベースの利点を活かしつつ、クリーンアーキテクチャの恩恵を段階的に享受**し、長期的な保守性と拡張性を確保します。特にPhase 6.10により、Infrastructure層とDomain層の境界が完全に明確化され、Clean Architectureの原則に完全準拠したシステムが実現されます。
