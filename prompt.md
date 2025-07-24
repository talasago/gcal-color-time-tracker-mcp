# Google Calendar 色別時間集計MCPサーバー（mcp-rb版）

## 要件

Googleカレンダーの色別時間集計を行うMCPサーバーをmcp-rbフレームワークで実装してください。

### 機能要件

1. **色別時間集計**: 指定期間のカレンダーイベントを色毎に時間集計
2. **MCPツール**: `analyze_calendar` ツールで分析実行
3. **MCPリソース**: 認証状態やユーザー情報をリソースとして提供
4. **複数ユーザー対応**: データベースを使わずにローカルファイルで管理
5. **簡単な認証フロー**: OAuth 2.0による認証

### 技術要件

- **mcp-rb**フレームワークを使用
- **Google Calendar API**を使用（google-api-client gem）
- **OAuth 2.0**による認証
- **ファイルベース**でのトークン管理（データベース不要）
- **MCPプロトコル**準拠

### 運用要件

- **管理者**: Google Cloud Console設定は一度だけ
- **他のユーザー**: Claude経由で認証・分析実行
- **再認証頻度**: 可能な限り少なく（リフレッシュトークン活用）

## 実装内容

### 1. プロジェクト構成

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

### 2. Gemfile

```ruby
source 'https://rubygems.org'

gem 'mcp-rb'
gem 'google-api-client'
gem 'dotenv'
gem 'json'
gem 'digest'
gem 'fileutils'

group :development, :test do
  gem 'rspec'
  gem 'pry'
end
```

### 3. Gemspec

```ruby
# calendar_color_mcp.gemspec
Gem::Specification.new do |spec|
  spec.name          = "calendar_color_mcp"
  spec.version       = "1.0.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]
  spec.summary       = "Google Calendar Color-based Time Analytics MCP Server"
  spec.description   = "MCPサーバーでGoogleカレンダーの色別時間集計を行います"
  spec.homepage      = "https://github.com/yourusername/calendar-color-mcp"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{lib,bin}/**/*") + %w[README.md Gemfile]
  spec.bindir        = "bin"
  spec.executables   = ["calendar-color-mcp"]
  spec.require_paths = ["lib"]

  spec.add_dependency "mcp-rb"
  spec.add_dependency "google-api-client"
  spec.add_dependency "dotenv"
end
```

### 4. メインサーバー実装

```ruby
# lib/calendar_color_mcp.rb
require 'mcp'
require 'dotenv/load'
require_relative 'calendar_color_mcp/server'

module CalendarColorMCP
  def self.run
    server = CalendarColorMCP::Server.new
    server.run
  end
end
```

```ruby
# lib/calendar_color_mcp/server.rb
require 'mcp'
require_relative 'google_calendar_client'
require_relative 'time_analyzer'
require_relative 'user_manager'
require_relative 'auth_manager'

module CalendarColorMCP
  class Server < MCP::Server
    def initialize
      super(
        name: "calendar-color-analytics",
        version: "1.0.0",
        description: "Google Calendar color-based time analytics MCP server"
      )
      
      @user_manager = UserManager.new
      @auth_manager = AuthManager.new
      
      setup_tools
      setup_resources
    end

    private

    def setup_tools
      # カレンダー分析ツール
      add_tool(
        name: "analyze_calendar",
        description: "指定期間のGoogleカレンダーイベントを色別に時間集計します",
        parameters: {
          type: "object",
          properties: {
            user_id: {
              type: "string",
              description: "ユーザーID（認証に使用）"
            },
            start_date: {
              type: "string",
              pattern: "^\\d{4}-\\d{2}-\\d{2}$",
              description: "開始日（YYYY-MM-DD形式）"
            },
            end_date: {
              type: "string", 
              pattern: "^\\d{4}-\\d{2}-\\d{2}$",
              description: "終了日（YYYY-MM-DD形式）"
            }
          },
          required: ["user_id", "start_date", "end_date"]
        }
      ) do |params|
        handle_analyze_calendar(params)
      end

      # 認証開始ツール
      add_tool(
        name: "start_auth",
        description: "Google Calendar認証を開始します",
        parameters: {
          type: "object",
          properties: {
            user_id: {
              type: "string",
              description: "ユーザーID"
            }
          },
          required: ["user_id"]
        }
      ) do |params|
        handle_start_auth(params)
      end

      # 認証状態確認ツール
      add_tool(
        name: "check_auth_status",
        description: "認証状態を確認します",
        parameters: {
          type: "object",
          properties: {
            user_id: {
              type: "string",
              description: "ユーザーID"
            }
          },
          required: ["user_id"]
        }
      ) do |params|
        handle_check_auth_status(params)
      end
    end

    def setup_resources
      # ユーザー認証状態リソース
      add_resource(
        uri: "auth://users",
        name: "User Authentication Status",
        description: "全ユーザーの認証状態一覧",
        mime_type: "application/json"
      ) do
        get_users_auth_status
      end

      # カレンダー色定義リソース
      add_resource(
        uri: "calendar://colors",
        name: "Calendar Colors",
        description: "Googleカレンダーの色定義",
        mime_type: "application/json"
      ) do
        get_calendar_colors
      end
    end

    # ツールハンドラー
    def handle_analyze_calendar(params)
      user_id = params["user_id"]
      start_date = Date.parse(params["start_date"])
      end_date = Date.parse(params["end_date"])

      # 認証確認
      unless @user_manager.authenticated?(user_id)
        auth_url = @auth_manager.get_auth_url(user_id)
        return {
          success: false,
          error: "認証が必要です",
          auth_url: auth_url
        }
      end

      # 分析実行
      begin
        client = GoogleCalendarClient.new(user_id)
        events = client.get_events(start_date, end_date)
        
        analyzer = TimeAnalyzer.new
        result = analyzer.analyze(events, start_date, end_date)
        
        {
          success: true,
          user_id: user_id,
          period: {
            start_date: start_date.to_s,
            end_date: end_date.to_s,
            days: (end_date - start_date).to_i + 1
          },
          analysis: result[:color_breakdown],
          summary: result[:summary],
          formatted_output: format_analysis_output(user_id, result)
        }
      rescue Google::Apis::AuthorizationError
        auth_url = @auth_manager.get_auth_url(user_id)
        {
          success: false,
          error: "認証の更新が必要です",
          auth_url: auth_url
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def handle_start_auth(params)
      user_id = params["user_id"]
      auth_url = @auth_manager.get_auth_url(user_id)
      
      {
        success: true,
        user_id: user_id,
        auth_url: auth_url,
        instructions: "上記URLにアクセスして認証を完了してください。認証後、再度分析を実行できます。"
      }
    end

    def handle_check_auth_status(params)
      user_id = params["user_id"]
      authenticated = @user_manager.authenticated?(user_id)
      
      result = {
        success: true,
        user_id: user_id,
        authenticated: authenticated
      }
      
      unless authenticated
        result[:auth_url] = @auth_manager.get_auth_url(user_id)
        result[:message] = "認証が必要です"
      else
        result[:message] = "認証済みです"
      end
      
      result
    end

    # リソースハンドラー
    def get_users_auth_status
      users = @user_manager.list_users
      auth_status = users.map do |user_id|
        {
          user_id: user_id,
          authenticated: @user_manager.authenticated?(user_id),
          last_auth: @user_manager.last_auth_time(user_id)
        }
      end
      
      {
        total_users: users.count,
        users: auth_status
      }.to_json
    end

    def get_calendar_colors
      TimeAnalyzer::COLOR_NAMES.to_json
    end

    # ヘルパーメソッド
    def format_analysis_output(user_id, result)
      output = ["📊 #{user_id} の色別時間集計結果:", "=" * 50, ""]
      
      result[:color_breakdown].each do |color_name, data|
        hours = data[:total_hours]
        minutes = ((hours % 1) * 60).round
        
        output << "🎨 #{color_name}:"
        output << "  時間: #{hours.to_i}時間#{minutes}分"
        output << "  イベント数: #{data[:event_count]}件"
        
        if data[:events].any?
          main_events = data[:events].first(3).map { |e| e[:title] }.join(", ")
          output << "  主なイベント: #{main_events}"
        end
        output << ""
      end
      
      summary = result[:summary]
      output << "📈 サマリー:"
      output << "  総時間: #{summary[:total_hours]}時間"
      output << "  総イベント数: #{summary[:total_events]}件"
      
      if summary[:most_used_color]
        most_used = summary[:most_used_color]
        output << "  最も使用された色: #{most_used[:name]} (#{most_used[:hours]}時間、#{most_used[:percentage]}%)"
      end
      
      output.join("\n")
    end
  end
end
```

### 5. Google Calendar クライアント

```ruby
# lib/calendar_color_mcp/google_calendar_client.rb
require 'google/apis/calendar_v3'
require 'googleauth'

module CalendarColorMCP
  class GoogleCalendarClient
    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

    def initialize(user_id)
      @user_id = user_id
      @service = Google::Apis::CalendarV3::CalendarService.new
      @user_manager = UserManager.new
      authorize_service
    end

    def get_events(start_date, end_date)
      @service.list_events(
        'primary',
        time_min: start_date.beginning_of_day.rfc3339,
        time_max: end_date.end_of_day.rfc3339,
        single_events: true,
        order_by: 'startTime'
      ).items
    rescue Google::Apis::AuthorizationError => e
      raise e
    rescue => e
      raise "カレンダーイベントの取得に失敗しました: #{e.message}"
    end

    private

    def authorize_service
      credentials = @user_manager.load_credentials(@user_id)
      raise Google::Apis::AuthorizationError, "認証情報が見つかりません" unless credentials
      
      @service.authorization = credentials
      
      # トークンの有効性確認
      if credentials.expired?
        credentials.refresh!
        @user_manager.save_credentials(@user_id, credentials)
      end
    end
  end
end
```

### 6. 時間分析ロジック

```ruby
# lib/calendar_color_mcp/time_analyzer.rb
require 'date'

module CalendarColorMCP
  class TimeAnalyzer
    COLOR_NAMES = {
      1 => '薄紫', 2 => '緑', 3 => '紫', 4 => '赤', 5 => '黄',
      6 => 'オレンジ', 7 => '水色', 8 => '灰色', 9 => '青', 
      10 => '濃い緑', 11 => '濃い赤'
    }.freeze

    def analyze(events, start_date, end_date)
      color_breakdown = analyze_by_color(events)
      summary = generate_summary(color_breakdown, events.count)
      
      {
        color_breakdown: color_breakdown,
        summary: summary
      }
    end

    private

    def analyze_by_color(events)
      color_data = {}
      
      events.each do |event|
        color_id = event.color_id&.to_i || 9  # デフォルトは青
        color_name = COLOR_NAMES[color_id] || "不明 (#{color_id})"
        
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
      if event.start.date_time && event.end.date_time
        # 通常のイベント（時刻指定）
        duration_seconds = event.end.date_time - event.start.date_time
        duration_seconds / 3600.0  # 時間に変換
      elsif event.start.date && event.end.date
        # 終日イベント
        start_date = Date.parse(event.start.date)
        end_date = Date.parse(event.end.date)
        (end_date - start_date).to_i * 24.0
      else
        # その他（時間不明）
        0.0
      end
    end

    def format_event_time(event)
      if event.start.date_time
        event.start.date_time.strftime('%Y-%m-%d %H:%M')
      elsif event.start.date
        "#{event.start.date}（終日）"
      else
        '時間不明'
      end
    end

    def generate_summary(color_breakdown, total_events)
      total_hours = color_breakdown.values.sum { |data| data[:total_hours] }
      
      most_used_color = color_breakdown.first if color_breakdown.any?
      
      summary = {
        total_hours: total_hours.round(2),
        total_events: total_events
      }
      
      if most_used_color
        color_name, color_data = most_used_color
        percentage = total_hours > 0 ? ((color_data[:total_hours] / total_hours) * 100).round(1) : 0
        
        summary[:most_used_color] = {
          name: color_name,
          hours: color_data[:total_hours],
          percentage: percentage
        }
      end
      
      summary
    end
  end
end
```

### 7. ユーザー管理

```ruby
# lib/calendar_color_mcp/user_manager.rb
require 'json'
require 'digest'
require 'fileutils'

module CalendarColorMCP
  class UserManager
    def initialize
      @tokens_dir = File.join(Dir.pwd, 'user_tokens')
      FileUtils.mkdir_p(@tokens_dir) unless Dir.exist?(@tokens_dir)
    end

    def authenticated?(user_id)
      token_file = token_file_path(user_id)
      File.exist?(token_file) && valid_token?(user_id)
    end

    def save_credentials(user_id, credentials)
      token_data = {
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token,
        expires_at: credentials.expires_at&.to_i,
        saved_at: Time.now.to_i
      }
      
      File.write(token_file_path(user_id), token_data.to_json)
    end

    def load_credentials(user_id)
      token_file = token_file_path(user_id)
      return nil unless File.exist?(token_file)
      
      token_data = JSON.parse(File.read(token_file))
      
      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        refresh_token: token_data['refresh_token'],
        access_token: token_data['access_token']
      )
      
      if token_data['expires_at']
        credentials.expires_at = Time.at(token_data['expires_at'])
      end
      
      credentials
    rescue JSON::ParserError, KeyError => e
      puts "トークンファイルの読み込みエラー: #{e.message}"
      nil
    end

    def list_users
      Dir.glob(File.join(@tokens_dir, '*.json')).map do |file|
        basename = File.basename(file, '.json')
        # ハッシュ化されたユーザーIDから元のIDは復元できないため、
        # ファイル名をそのまま返す（実際の運用では別途管理が必要）
        basename
      end
    end

    def last_auth_time(user_id)
      token_file = token_file_path(user_id)
      return nil unless File.exist?(token_file)
      
      token_data = JSON.parse(File.read(token_file))
      Time.at(token_data['saved_at']).strftime('%Y-%m-%d %H:%M:%S') if token_data['saved_at']
    rescue
      nil
    end

    private

    def token_file_path(user_id)
      hashed_id = hash_user_id(user_id)
      File.join(@tokens_dir, "#{hashed_id}.json")
    end

    def hash_user_id(user_id)
      Digest::SHA256.hexdigest(user_id.to_s)
    end

    def valid_token?(user_id)
      credentials = load_credentials(user_id)
      return false unless credentials
      
      # 基本的な有効性チェック
      credentials.access_token && credentials.refresh_token
    rescue
      false
    end
  end
end
```

### 8. 認証管理

```ruby
# lib/calendar_color_mcp/auth_manager.rb
require 'google/apis/calendar_v3'
require 'googleauth'

module CalendarColorMCP
  class AuthManager
    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
    REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'  # OOB flow for CLI

    def initialize
      @user_manager = UserManager.new
    end

    def get_auth_url(user_id)
      client_id = Google::Auth::ClientId.new(
        ENV['GOOGLE_CLIENT_ID'],
        ENV['GOOGLE_CLIENT_SECRET']
      )
      
      authorizer = Google::Auth::WebUserAuthorizer.new(
        client_id, 
        [SCOPE], 
        Google::Auth::Stores::FileTokenStore.new(file: '/dev/null'),  # 一時的
        REDIRECT_URI
      )
      
      url = authorizer.get_authorization_url(login_hint: user_id)
      
      # 手動認証の説明を含むURL
      {
        url: url,
        instructions: [
          "1. 上記URLにアクセスしてください",
          "2. Googleアカウントでログインし、権限を許可してください", 
          "3. 表示された認証コードをコピーしてください",
          "4. 認証コード: [ここに認証コードを貼り付けて、以下のコマンドを実行]",
          "   echo 'AUTH_CODE=<認証コード>' >> .env",
          "   # その後、再度分析を実行してください"
        ].join("\n")
      }
    end

    def complete_auth(user_id, auth_code)
      client_id = Google::Auth::ClientId.new(
        ENV['GOOGLE_CLIENT_ID'],
        ENV['GOOGLE_CLIENT_SECRET']
      )
      
      authorizer = Google::Auth::WebUserAuthorizer.new(
        client_id,
        [SCOPE],
        Google::Auth::Stores::FileTokenStore.new(file: '/dev/null'),
        REDIRECT_URI
      )
      
      credentials = authorizer.get_credentials_from_code(
        user_id: user_id,
        code: auth_code,
        scope: [SCOPE]
      )
      
      @user_manager.save_credentials(user_id, credentials)
      
      {
        success: true,
        message: "認証が完了しました",
        user_id: user_id
      }
    rescue => e
      {
        success: false,
        error: "認証に失敗しました: #{e.message}"
      }
    end
  end
end
```

### 9. 実行可能ファイル

```ruby
#!/usr/bin/env ruby
# bin/calendar-color-mcp

require_relative '../lib/calendar_color_mcp'

CalendarColorMCP.run
```

### 10. 環境設定

```bash
# .env.example
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Optional: Enable debug logging
DEBUG=true
```

### 11. 使用方法

#### インストール・セットアップ
```bash
# 依存関係インストール
bundle install

# 環境変数設定
cp .env.example .env
# .envファイルを編集してGoogle OAuth認証情報を設定

# 実行権限付与
chmod +x bin/calendar-color-mcp

# MCPサーバー起動
./bin/calendar-color-mcp
```

#### Claude での使用例

```
# カレンダー分析
analyze_calendar({
  "user_id": "tanaka", 
  "start_date": "2024-07-01", 
  "end_date": "2024-07-07"
})

# 認証開始
start_auth({"user_id": "tanaka"})

# 認証状態確認
check_auth_status({"user_id": "tanaka"})
```

#### リソース参照例

```
# 全ユーザーの認証状態
auth://users

# カレンダー色定義
calendar://colors
```

## mcp-rbの特徴

### ✅ **MCPプロトコル準拠**
- Claude との標準的な通信
- ツール・リソース・プロンプトの標準実装
- 自動的なエラーハンドリング

### ✅ **Ruby らしい実装**
- オブジェクト指向設計
- モジュール分離
- Rubyの慣習に従った構造

### ✅ **拡張性**
- 新しいツールの簡単な追加
- リソースの動的提供
- カスタムプロンプトの実装

完全に動作するmcp-rb実装を作成してください。
